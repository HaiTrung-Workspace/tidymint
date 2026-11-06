/**
 * Tidymint feedback & newsletter collector (Google Apps Script).
 * Appends one row per submission to the "Submissions" sheet of the spreadsheet this script is bound to.
 *
 * Deploy: Extensions > Apps Script > paste this file > Deploy > New deployment > Web app
 *         Execute as: Me, Who has access: Anyone. Copy the /exec URL into Backend.endpoint.
 */
const SHEET = 'Submissions';
const COLUMNS = ['time', 'source', 'type', 'email', 'newsletter', 'consent', 'consentVersion',
                 'message', 'app', 'macos', 'model', 'lang', 'answer', 'reasons'];
const MAX_LEN = 5000;

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents || '{}');
    const email = String(data.email || '').trim();
    // The in-app "Is Tidymint helping you?" card sends no email: one of three answers, optional reasons and a line.
    const checkin = String(data.type || '') === 'checkin';
    if (checkin) {
      if (!['helpful', 'okay', 'not'].includes(String(data.answer || ''))) return out('error: answer');
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return out('error: email');
    // Simple flood guard: at most 5 submissions per email per hour (per app version for check-ins, which carry no email).
    const cache = CacheService.getScriptCache();
    const key = 'n_' + (checkin ? 'checkin_' + String(data.app || '') : email.toLowerCase());
    const limit = checkin ? 500 : 5;
    const n = Number(cache.get(key) || 0);
    if (n >= limit) return out('error: rate');
    cache.put(key, String(n + 1), 3600);

    const sh = sheet();
    const row = COLUMNS.map(c => c === 'time' ? new Date() : String(data[c] || '').slice(0, MAX_LEN));
    sh.appendRow(row);
    return out('ok');
  } catch (err) {
    return out('error: ' + err);
  }
}

// GET ?stats=1: aggregate counts of the in-app check-in answers (helpful / okay / not), all time and the last
// 24 hours, so the daily report can read them without opening the sheet. Counts only: no text, no email, no row.
function doGet(e) {
  if (!(e && e.parameter && e.parameter.stats)) return out('Tidymint collector is running');
  try {
    const sh = sheet();
    const rows = sh.getLastRow() > 1 ? sh.getRange(2, 1, sh.getLastRow() - 1, COLUMNS.length).getValues() : [];
    const iT = COLUMNS.indexOf('time'), iType = COLUMNS.indexOf('type'), iA = COLUMNS.indexOf('answer'), iM = COLUMNS.indexOf('message');
    const since = Date.now() - 24 * 3600 * 1000;
    const zero = () => ({ helpful: 0, okay: 0, not: 0, with_message: 0 });
    const all = zero(), day = zero();
    let last = null, feedback = 0, feedbackDay = 0;
    for (const r of rows) {
      const t = r[iT] instanceof Date ? r[iT].getTime() : Date.parse(r[iT]);
      if (String(r[iType]) !== 'checkin') { feedback++; if (t >= since) feedbackDay++; continue; }
      const a = String(r[iA]); if (!(a in all)) continue;
      all[a]++; if (String(r[iM] || '').trim()) all.with_message++;
      if (t >= since) { day[a]++; if (String(r[iM] || '').trim()) day.with_message++; }
      if (!last || t > last) last = t;
    }
    const body = JSON.stringify({ generated: new Date().toISOString(), checkin_all: all, checkin_24h: day,
      checkin_last_at: last ? new Date(last).toISOString() : null, feedback_all: feedback, feedback_24h: feedbackDay });
    return ContentService.createTextOutput(body).setMimeType(ContentService.MimeType.JSON);
  } catch (err) { return out('error: ' + err); }
}

function sheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(SHEET);
  if (!sh) {
    sh = ss.insertSheet(SHEET);
    sh.appendRow(COLUMNS);
    sh.setFrozenRows(1);
  }
  return sh;
}

function out(text) { return ContentService.createTextOutput(text).setMimeType(ContentService.MimeType.TEXT); }
