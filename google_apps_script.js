// Google Apps Script — вставь этот код в script.google.com
// Инструкция по настройке ниже.

// ШАГ 1. Открой script.google.com, создай новый проект.
// ШАГ 2. Вставь весь этот код вместо содержимого редактора.
// ШАГ 3. Измени SPREADSHEET_ID на ID твоей Google таблицы
//         (это часть URL: docs.google.com/spreadsheets/d/СЮДА/edit)
// ШАГ 4. Нажми "Развернуть" → "Новое развёртывание" → тип "Веб-приложение"
//         Выполнять от имени: Я, Доступ: Все.
// ШАГ 5. Скопируй URL развёртывания и вставь его в приложении: Настройки → Google Sheets.
// ВАЖНО: при обновлении кода нужно создавать НОВОЕ развёртывание (не редактировать старое).

const SPREADSHEET_ID = "ВАШ_ID_ТАБЛИЦЫ_СЮДА";

// Индекс столбца ID в листе Обмены (1-based). ID хранится в скрытом последнем столбце.
const EXCHANGE_COLS = 8; // Дата | Статус | Партнёр | Отдаю | Кол-во отдаю | Получаю | Кол-во получаю | ID

function doGet(e) {
  try {
    const raw = e.parameter.payload;
    if (!raw) return ok("no payload");
    const data = JSON.parse(raw);
    return handleData(data);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ error: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    return handleData(data);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ error: err.message }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function handleData(data) {
    const event = data.event;
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);

    if (event === "purchase") {
      handlePurchase(ss, data);
    } else if (event === "exchange_created") {
      handleExchangeCreated(ss, data);
    } else if (event === "exchange_updated") {
      handleExchangeUpdated(ss, data);
    } else if (event === "exchange_completed") {
      handleExchangeCompleted(ss, data);
    } else if (event === "exchange_cancelled") {
      handleExchangeCancelled(ss, data);
    } else if (event === "collection") {
      handleCollection(ss, data);
    }

    return ok("ok");
}

// MARK: - Коллекция

function handleCollection(ss, data) {
  const sheetName = "Коллекция";
  let sheet = ss.getSheetByName(sheetName);

  // Очищаем только при первом чанке (clear:true)
  if (data.clear !== false) {
    if (sheet) {
      sheet.clearContents();
      sheet.clearFormats();
    } else {
      sheet = ss.insertSheet(sheetName);
    }
    const headers = ["Сборная", "Повторки", "Ищу"];
    sheet.appendRow(headers);
    const headerRange = sheet.getRange(1, 1, 1, headers.length);
    headerRange.setFontWeight("bold");
    headerRange.setBackground("#E3F2FD");
  }

  if (!sheet) sheet = ss.getSheetByName(sheetName);

  const teams = data.teams || [];
  let lastGroup = data.prev_group || null;

  teams.forEach(function(t) {
    if (t.group !== lastGroup) {
      if (lastGroup !== null) {
        sheet.appendRow(["", "", ""]);
      }
      lastGroup = t.group;
    }
    sheet.appendRow([t.team, t.duplicates || "—", t.missing || "—"]);
  });

  sheet.autoResizeColumns(1, 3);
}

// MARK: - Покупки

function handlePurchase(ss, data) {
  const sheet = getOrCreateSheet(ss, "Покупки", ["Дата", "Тип", "Количество", "Цена за ед. (Br)", "Итого (Br)", "Наклеек"]);
  const date = formatDate(data.date);
  sheet.appendRow([date, data.kind, data.quantity, data.price_each, data.total_cost, data.sticker_count]);
}

// MARK: - Обмены

function handleExchangeCreated(ss, data) {
  const sheet = getOrCreateSheet(ss, "Обмены", exchangeHeaders());
  const row = exchangeRow("Активный", data);
  sheet.appendRow(row);
  colorLastRow(sheet, "#E8F5E9"); // светло-зелёный
}

function handleExchangeUpdated(ss, data) {
  const sheet = getOrCreateSheet(ss, "Обмены", exchangeHeaders());
  const rowIndex = findRowById(sheet, data.id, EXCHANGE_COLS);

  if (rowIndex > 0) {
    // Обновляем существующую строку, сохраняем статус и дату
    const existingStatus = sheet.getRange(rowIndex, 2).getValue();
    const existingDate   = sheet.getRange(rowIndex, 1).getValue();
    const newRow = [
      existingDate,
      existingStatus,
      data.partner || "—",
      data.giving   || "—",
      data.giving_count,
      data.wanting  || "—",
      data.wanting_count,
      data.id
    ];
    sheet.getRange(rowIndex, 1, 1, EXCHANGE_COLS).setValues([newRow]);
  } else {
    // Строки нет — создаём как новую
    sheet.appendRow(exchangeRow("Активный", data));
    colorLastRow(sheet, "#E8F5E9");
  }
}

function handleExchangeCompleted(ss, data) {
  const sheet = getOrCreateSheet(ss, "Обмены", exchangeHeaders());
  const rowIndex = findRowById(sheet, data.id, EXCHANGE_COLS);

  if (rowIndex > 0) {
    sheet.getRange(rowIndex, 2).setValue("Завершён");
    sheet.getRange(rowIndex, 1).setValue(formatDate(data.date));
    sheet.getRange(rowIndex, 1, 1, EXCHANGE_COLS).setBackground("#E3F2FD"); // светло-синий
  } else {
    const row = exchangeRow("Завершён", data);
    sheet.appendRow(row);
    colorLastRow(sheet, "#E3F2FD");
  }
}

function handleExchangeCancelled(ss, data) {
  const sheet = getOrCreateSheet(ss, "Обмены", exchangeHeaders());
  const rowIndex = findRowById(sheet, data.id, EXCHANGE_COLS);

  if (rowIndex > 0) {
    sheet.getRange(rowIndex, 2).setValue("Отменён");
    sheet.getRange(rowIndex, 1).setValue(formatDate(data.date));
    sheet.getRange(rowIndex, 1, 1, EXCHANGE_COLS).setBackground("#FAFAFA"); // серый
  } else {
    const row = exchangeRow("Отменён", data);
    sheet.appendRow(row);
    colorLastRow(sheet, "#FAFAFA");
  }
}

// MARK: - Helpers

function exchangeHeaders() {
  return ["Дата", "Статус", "Партнёр", "Отдаю", "Кол-во отдаю", "Получаю", "Кол-во получаю", "ID"];
}

function exchangeRow(status, data) {
  return [
    formatDate(data.date),
    status,
    data.partner || "—",
    data.giving   || "—",
    data.giving_count,
    data.wanting  || "—",
    data.wanting_count,
    data.id
  ];
}

function findRowById(sheet, id, idCol) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return -1;
  const values = sheet.getRange(2, idCol, lastRow - 1, 1).getValues();
  for (let i = 0; i < values.length; i++) {
    if (values[i][0] === id) return i + 2;
  }
  return -1;
}

function getOrCreateSheet(ss, name, headers) {
  let sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
    sheet.appendRow(headers);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight("bold");
    // Скрываем столбец ID в Обменах
    if (name === "Обмены") {
      sheet.hideColumns(EXCHANGE_COLS);
    }
  }
  return sheet;
}

function colorLastRow(sheet, color) {
  const last = sheet.getLastRow();
  sheet.getRange(last, 1, 1, sheet.getLastColumn()).setBackground(color);
}

function formatDate(iso) {
  return new Date(iso).toLocaleString("ru-RU", { timeZone: "Europe/Minsk" });
}

function ok(msg) {
  return ContentService
    .createTextOutput(JSON.stringify({ status: msg }))
    .setMimeType(ContentService.MimeType.JSON);
}
