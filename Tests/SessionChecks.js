const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../App/CourseVilleScript.swift'), 'utf8');
const script = source.split('#"""', 2)[1]?.split('"""#', 1)[0];
assert.ok(script, 'CourseVilleScript.fetchAssignments must exist');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const fetchAssignments = new AsyncFunction('previousItemsJSON', script);
const homeURL = 'https://www.mycourseville.com/?q=courseville&type=course&role=all';

global.location = {origin: 'https://www.mycourseville.com'};
global.DOMParser = class {
  parseFromString(html) {
    return {
      body: {textContent: html},
      querySelector: () => null,
      querySelectorAll: () => []
    };
  }
};
global.document = {querySelectorAll: () => []};

async function check(description, responses, expected) {
  let index = 0;
  global.fetch = async () => {
    assert.ok(index < responses.length, `${description}: unexpected fetch`);
    return responses[index++];
  };
  const result = JSON.parse(await fetchAssignments('[]'));
  assert.deepEqual(result, expected, description);
}

const response = (text, url = homeURL) => ({ok: true, url, text: async () => text});

(async () => {
  await check('expired session on the login page',
    [response('Please login with either of the following choices.')],
    {authRequired: true, items: []});
  await check('session redirected to CU sign-in',
    [response('', 'https://account.chula.ac.th/login')],
    {authRequired: true, items: []});
  await check('signed-in account with no assignments',
    [response('Signed on as Example User'), response(JSON.stringify({html: ''}))],
    {authRequired: false, items: []});
  console.log('Session checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
