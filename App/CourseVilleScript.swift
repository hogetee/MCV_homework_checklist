import Foundation

enum CourseVilleScript {
    // Reads pages only in the WKWebView session the student signed in to.
    // myCourseVille does not publish a stable assignment API for this app.
    static let fetchAssignments = #"""
    const oldItems = JSON.parse(previousItemsJSON);
    const root = location.origin + '/';
    const clean = value => (value || '').replace(/\s+/g, ' ').trim();
    const worksheetURL = href => {
      try {
        const url = new URL(href, root);
        const q = url.searchParams.get('q') || '';
        return url.hostname === 'www.mycourseville.com' &&
          /^courseville\/worksheet\/\d+\/\d+$/.test(q) ? url.href : null;
      } catch { return null; }
    };

    const panelResponse = await fetch('/?q=courseville/ajax/getactivepanelcontent', {
      method: 'POST', credentials: 'same-origin',
      headers: {'X-Requested-With': 'XMLHttpRequest'}
    });
    if (!panelResponse.ok) throw new Error('Unable to load the course list');
    let panel;
    try { panel = await panelResponse.json(); }
    catch { throw new Error('Please sign in to myCourseVille first'); }
    if (typeof panel.html !== 'string') throw new Error('The course list format changed');
    const panelDoc = new DOMParser().parseFromString(panel.html, 'text/html');
    const found = new Map();

    // The home panel highlights urgent work, including items that may no longer
    // appear on a course's first assignment-list page.
    for (const anchor of panelDoc.querySelectorAll('a[href]')) {
      const href = worksheetURL(anchor.getAttribute('href'));
      if (!href) continue;
      let row = anchor;
      for (let depth = 0; depth < 4 && row.parentElement; depth++) {
        row = row.parentElement;
        if (/dues? in/i.test(row.textContent || '')) break;
      }
      const text = clean(row?.textContent || anchor.textContent);
      const quoted = text.match(/[“"]([^”"]+)[”"]/);
      const strong = clean(row?.querySelector('strong')?.textContent);
      const title = quoted?.[1] || strong || clean(anchor.textContent);
      const course = (text.match(/\b\d{6,8}(?:\.\d+)?\b/) || [])[0] || '';
      const dueText = (text.match(/dues? in\s+[^,.]+/i) || [])[0] || '';
      found.set(href, {id: href, title, course, url: href,
        dueText, dueRaw: null, submittedRaw: null, detailLoaded: false});
    }

    // Course cards on the signed-in home page identify the student's current
    // courses. The assignment list includes work beyond the seven-day panel.
    let courseDoc = document;
    try {
      const response = await fetch('/?q=courseville&type=course&role=all',
        {credentials: 'same-origin'});
      if (response.ok && response.url.startsWith(root)) {
        courseDoc = new DOMParser().parseFromString(await response.text(), 'text/html');
      }
    } catch { /* The currently open home page can still supply course cards. */ }
    const courses = new Map();
    const courseNameFor = anchor => {
      const specific = clean(anchor.querySelector(
        '.course-name, .cv-course-name, .course-title, .cv-course-title, h1, h2, h3, h4'
      )?.textContent);
      if (specific && !/\b\d{6,8}(?:\.\d+)?\b/.test(specific)) {
        return clean(specific.replace(/\s*\[\s*section[^\]]*\]/ig, ' '));
      }
      const text = clean(anchor.textContent || anchor.getAttribute('aria-label') ||
        anchor.getAttribute('title'));
      let name = clean(text
        .replace(/\b\d{6,8}(?:\.\d+)?\b/g, ' ')
        .replace(/\(?\s*\d{4}\s*\/\s*\d+\s*\)?/g, ' ')
        .replace(/\s*\[\s*section[^\]]*\]/ig, ' ')
        .replace(/\bLMS\s+Student\b/ig, ' '));
      const words = name.split(' ');
      for (let midpoint = 1; midpoint < words.length; midpoint++) {
        const first = words.slice(0, midpoint).join(' ');
        const second = words.slice(midpoint).join(' ');
        if (first && first.toLowerCase() === second.toLowerCase()) {
          name = first;
          break;
        }
      }
      return name;
    };
    for (const source of [courseDoc, document]) {
      for (const anchor of source.querySelectorAll('a[href]')) {
        let url;
        try { url = new URL(anchor.getAttribute('href'), root); } catch { continue; }
        if (url.hostname !== 'www.mycourseville.com') continue;
        const match = (url.searchParams.get('q') || '').match(/^courseville\/course\/(\d+)$/);
        if (!match) continue;
        const code = clean(anchor.textContent).match(/\b\d{6,8}(?:\.\d+)?\b/);
        if (!courses.has(match[1])) {
          courses.set(match[1], {
            code: code?.[0] || '',
            name: courseNameFor(anchor)
          });
        }
      }
    }

    const addRows = (rows, course) => {
      for (const row of rows) {
        const anchor = row.querySelector('a[href*="worksheet/"]');
        const href = anchor && worksheetURL(anchor.getAttribute('href'));
        if (!href) continue;
        const dueLabel = clean(row.querySelector('.cv-due-col .sr-only')?.textContent);
        const dueMatch = dueLabel.match(/Due on\s+(.+?)\s+at\s+(\d{1,2}:\d{2})/i);
        const dueRaw = dueMatch ? dueMatch[1] + ' ' + dueMatch[2] : null;
        const feedback = row.querySelectorAll('td')[5];
        const feedbackText = clean(feedback?.textContent);
        const submitted = feedbackText.match(/Submitted at\s+(\d{1,2}\s+[A-Za-z]+\s+\d{4}\s+\d{2}:\d{2}:\d{2})/i);
        const pending = !!feedback?.querySelector('[aria-label="No submission"]');
        found.set(href, {id: href, title: clean(anchor.textContent), course, url: href,
          dueText: dueLabel, dueRaw, submittedRaw: submitted?.[1] || null,
          detailLoaded: !!submitted || pending});
      }
    };

    for (const [courseID, courseInfo] of Array.from(courses).slice(0, 30)) {
      try {
        const response = await fetch('/?q=courseville/course/' + courseID + '/assignment',
          {credentials: 'same-origin'});
        if (!response.ok || !response.url.startsWith(root)) continue;
        const page = new DOMParser().parseFromString(await response.text(), 'text/html');
        addRows(page.querySelectorAll('tr'), courseInfo.code || 'myCourseVille');

        // The site shows five rows at a time. Follow the same read-only
        // "Load more items" endpoint to include older overdue work too.
        const loadPanel = page.querySelector('#courseville-assignment-list-loadmore-panel');
        let next = Number(loadPanel?.getAttribute('data-next'));
        let pages = 0;
        while (loadPanel && Number.isFinite(next) && next >= 0 &&
               pages < 20 && found.size < 200) {
          pages++;
          const moreResponse = await fetch('/?q=courseville/ajax/loadmoreassignmentrows', {
            method: 'POST', credentials: 'same-origin',
            headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'X-Requested-With': 'XMLHttpRequest'},
            body: new URLSearchParams({cv_cid: courseID, next: String(next)}).toString()
          });
          if (!moreResponse.ok) break;
          const more = await moreResponse.json();
          if (more.status !== 1 || typeof more.data?.html !== 'string') break;
          const morePage = new DOMParser().parseFromString(
            '<table><tbody>' + more.data.html + '</tbody></table>', 'text/html');
          addRows(morePage.querySelectorAll('tr'), courseInfo.code || 'myCourseVille');
          if (more.all === true) break;
          const following = Number(more.next);
          if (!Number.isFinite(following) || following <= next) break;
          next = following;
        }
      } catch { /* Keep the home-panel and previously seen work. */ }
    }

    for (const old of oldItems) {
      const href = worksheetURL(old.url);
      if (href && !found.has(href)) {
        found.set(href, {id: href, title: old.title, course: old.course,
          courseName: old.courseName || '',
          url: href, dueText: old.dueText, dueRaw: null,
          submittedRaw: null, detailLoaded: false});
      }
    }
    for (const item of found.values()) {
      const query = new URL(item.url, root).searchParams.get('q') || '';
      const courseID = query.match(/^courseville\/worksheet\/(\d+)\/\d+$/)?.[1];
      const courseInfo = courseID && courses.get(courseID);
      if (!courseInfo) continue;
      if (!item.course || item.course === 'myCourseVille') item.course = courseInfo.code || item.course;
      if (courseInfo.name) item.courseName = courseInfo.name;
    }
    const items = Array.from(found.values()).slice(0, 200);
    for (const item of items) {
      if (item.detailLoaded && item.dueRaw) continue;
      try {
        const response = await fetch(item.url, {credentials: 'same-origin'});
        if (!response.ok || !response.url.startsWith(root)) continue;
        const work = new DOMParser().parseFromString(await response.text(), 'text/html');
        const body = clean(work.body?.textContent);
        if (!/My Work|Save\s*\/\s*Submit|latest submission/i.test(body)) continue;
        item.detailLoaded = true;
        item.dueRaw = (body.match(/due date\/time\.?\s*\(\s*(\d{1,2}-(?:[A-Za-z]{3}|\d{1,2})-\d{4}\s+\d{2}:\d{2})\s*\)/i) || [])[1] || item.dueRaw;
        item.submittedRaw = (body.match(/The latest submission was made at\s*(\d{1,2}-(?:[A-Za-z]{3}|\d{1,2})-\d{4}\s+\d{2}:\d{2}:\d{2})/i) || [])[1] || null;
      } catch { /* Keep the list's last known state. */ }
    }
    return JSON.stringify(items);
    """#
}
