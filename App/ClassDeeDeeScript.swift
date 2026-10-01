import Foundation

enum ClassDeeDeeScript {
    // Uses the same read-only endpoints and session as ClassDeeDee's own pages.
    static let fetchAssignments = #"""
    const oldItems = JSON.parse(previousItemsJSON);
    class AuthRequired extends Error {}
    const get = async path => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 20000);
      try {
        const response = await fetch(path, {credentials: 'same-origin', signal: controller.signal});
        if (response.status === 401 || new URL(response.url).pathname.startsWith('/login'))
          throw new AuthRequired();
        if (!response.ok) throw new Error('ClassDeeDee: HTTP ' + response.status);
        return await response.json();
      } finally { clearTimeout(timeout); }
    };
    const integer = value => value !== null && value !== undefined && value !== '' &&
      Number.isInteger(Number(value)) && Number(value) >= 0 ? Number(value) : null;
    const utc = raw => {
      if (typeof raw !== 'string' || !raw.trim()) return null;
      let value = raw.trim().replace(' ', 'T');
      if (!/(?:Z|[+-]\d\d:\d\d)$/i.test(value)) value += 'Z';
      const date = new Date(value);
      return Number.isNaN(date.getTime()) ? null : date.toISOString();
    };
    try {
      const user = await get('/api/users/me');
      if (!user || typeof user !== 'object' || user.uid == null) throw new AuthRequired();
      const courses = await get('/api/courses/me');
      if (!Array.isArray(courses)) throw new Error('Unable to read the ClassDeeDee course list');
      const valid = courses.filter(c => /^[A-Za-z0-9_-]+$/.test(c.courseid || ''));
      const terms = valid.map(c => String(c.academicyear || '') + '/' + String(c.semestercode || '')).sort();
      const latestTerm = terms.at(-1);
      const knownCourses = new Set(oldItems.map(item => item.course));
      const selected = valid.filter(c =>
        String(c.academicyear || '') + '/' + String(c.semestercode || '') === latestTerm ||
        knownCourses.has(c.courseid)).slice(0, 30);
      const items = [], failedCourses = [];
      for (const course of selected) {
        try {
          const rows = await get('/api/assignments/forSubmission?' +
            new URLSearchParams({courseid: course.courseid}));
          if (!Array.isArray(rows)) throw new Error('Unable to read the ClassDeeDee assignment list');
          // Reject incomplete records so they cannot erase a previously known review requirement.
          if (rows.some(row => !row || !row.uuid || typeof row.title !== 'string' ||
              !Object.hasOwn(row, 'my_submission') || !Object.hasOwn(row, 'peer_type')))
            throw new Error('The ClassDeeDee assignment format changed');
          for (const row of rows) {
            const submission = row.my_submission;
            const submitted = submission && typeof submission === 'object' &&
              (submission.submissionid != null || submission.submitdate != null);
            const minimum = integer(row.peer_min);
            const base = location.origin + '/courses/' + encodeURIComponent(course.courseid) + '/assignments/';
            items.push({
              id: 'classdeedee:' + course.courseid + ':' + row.uuid,
              title: row.title, course: course.courseid, courseName: course.coursename || null,
              url: base + 'submission/' + encodeURIComponent(row.uuid),
              dueRaw: utc(row.deadline), submittedRaw: utc(submission?.submitdate),
              state: submission === null ? 'pending' : submitted ? 'submitted' : 'unknown',
              reviewRequired: Number(row.peer_type) !== 0 && (minimum === null || minimum > 0),
              reviewStartsRaw: utc(row.rev_start_date), reviewDueRaw: utc(row.rev_end_date),
              reviewCount: integer(row.my_review_count), reviewMinimum: minimum,
              reviewURL: base + 'panel/' + encodeURIComponent(row.uuid)
            });
          }
        } catch (error) {
          if (error instanceof AuthRequired) throw error;
          failedCourses.push(course.courseid);
        }
      }
      if (selected.length && failedCourses.length === selected.length)
        throw new Error('Unable to load ClassDeeDee assignments; keeping the last synced data');
      return JSON.stringify({authRequired: false, items, failedCourses});
    } catch (error) {
      if (error instanceof AuthRequired)
        return JSON.stringify({authRequired: true, items: [], failedCourses: []});
      throw error;
    }
    """#
}
