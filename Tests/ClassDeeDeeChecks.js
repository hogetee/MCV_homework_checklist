const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../App/ClassDeeDeeScript.swift'), 'utf8');
const script = source.split('#"""', 2)[1]?.split('"""#', 1)[0];
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const sync = new AsyncFunction('previousItemsJSON', script);
const origin = 'https://classdeedee.cloud.cp.eng.chula.ac.th';
global.location = {origin};
const courses = [
  {courseid: 'current', coursename: 'Security', academicyear: 2026, semestercode: 'S1'},
  {courseid: 'old', coursename: 'Old', academicyear: 2025, semestercode: 'S1'}
];
const row = {uuid: 'one', title: 'Security task', deadline: '2026-10-01 16:59:00',
  my_submission: {submissionid: 1, submitdate: '2026-09-30T01:00:00'}, peer_type: 1,
  peer_min: 3, my_review_count: 2, rev_start_date: '2026-10-01T17:00:00', rev_end_date: '2026-10-04T16:59:00'};

function mock(routes) {
  global.fetch = async (url, options) => {
    assert.equal(options.credentials, 'same-origin');
    assert.ok(!options.method || options.method === 'GET', 'only read-only requests');
    assert.ok(Object.hasOwn(routes, url), 'unexpected endpoint: ' + url);
    const data = routes[url];
    const status = typeof data === 'number' ? data : 200;
    return {status, ok: status === 200, url: origin + url, json: async () => data};
  };
}
(async () => {
  mock({'/api/users/me': 401});
  assert.equal(JSON.parse(await sync('[]')).authRequired, true);
  mock({'/api/users/me': {uid: 'example'}, '/api/courses/me': courses,
    '/api/assignments/forSubmission?courseid=current': [row, {...row, uuid: 'two', my_submission: null}]});
  const result = JSON.parse(await sync('[]'));
  assert.equal(result.items.length, 2);
  assert.equal(result.items[0].courseName, 'Security');
  assert.equal(result.items[0].reviewCount, 2);
  assert.equal(result.items[0].reviewMinimum, 3);
  assert.equal(result.items[0].dueRaw, '2026-10-01T16:59:00.000Z');
  assert.equal(result.items[0].state, 'submitted');
  assert.equal(result.items[1].state, 'pending');
  assert.deepEqual(result.failedCourses, []);
  mock({'/api/users/me': {uid: 'example'}, '/api/courses/me': courses,
    '/api/assignments/forSubmission?courseid=current': [row],
    '/api/assignments/forSubmission?courseid=old': 503});
  const partial = JSON.parse(await sync(JSON.stringify([{course: 'old'}])));
  assert.deepEqual(partial.failedCourses, ['old'], 'keep cached tasks from failed courses');
  mock({'/api/users/me': {uid: 'example'}, '/api/courses/me': courses,
    '/api/assignments/forSubmission?courseid=current': 401});
  assert.equal(JSON.parse(await sync('[]')).authRequired, true);
  // Missing review/submission fields must not silently turn a task green.
  mock({'/api/users/me': {uid: 'example'}, '/api/courses/me': courses,
    '/api/assignments/forSubmission?courseid=current': [{uuid: 'one', title: 'Incomplete'}]});
  await assert.rejects(sync('[]'), /keeping the last synced data/);
  console.log('ClassDeeDee checks passed');
})().catch(error => { console.error(error); process.exitCode = 1; });
