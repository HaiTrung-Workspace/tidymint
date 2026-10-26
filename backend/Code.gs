/**
 * Tidymint feedback & newsletter collector (Google Apps Script).
 * Appends one row per submission to the "Submissions" sheet of the spreadsheet this script is bound to.
 *
 * Deploy: Extensions > Apps Script > paste this file > Deploy > New deployment > Web app
 *         Execute as: Me, Who has access: Anyone. Copy the /exec URL into Backend.endpoint.
 */
const SHEET = 'Submissions';
const COLUMNS = ['time', 'source', 'type', 'email', 'newsletter', 'consent', 'consentVersion',
                 'message', 'app', 'macos', 'model', 'lang'];
const MAX_LEN = 5000;

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents || '{}');
    const email = String(data.email || '').trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return out('error: email');
    // Simple flood guard: at most 5 submissions per email per hour.
    const cache = CacheService.getScriptCache();
    const key = 'n_' + email.toLowerCase();
    const n = Number(cache.get(key) || 0);
    if (n >= 5) return out('error: rate');
    cache.put(key, String(n + 1), 3600);

    const sh = sheet();
    const row = COLUMNS.map(c => c === 'time' ? new Date() : String(data[c] || '').slice(0, MAX_LEN));
    sh.appendRow(row);
    return out('ok');
  } catch (err) {
    return out('error: ' + err);
  }
}

function doGet() { return out('Tidymint collector is running'); }

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
