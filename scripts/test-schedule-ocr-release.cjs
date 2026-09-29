const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const client = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/services/ScheduleImportClient.ets'),
  'utf8'
);
const index = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/pages/Index.ets'),
  'utf8'
);
const moduleProfile = fs.readFileSync(
  path.join(root, 'entry/src/main/module.json5'),
  'utf8'
);

// Release must compile the platform OCR module instead of relying only on a server helper.
assert.match(client, /import \{ textRecognition \} from '@kit\.CoreVisionKit'/);
assert.match(client, /await textRecognition\.init\(\)/);
assert.match(client, /await textRecognition\.recognizeText\(/);
assert.equal(client.includes('CORE_VISION_TIMEOUT_MS'), false);
assert.equal(client.includes('withTimeout('), false);

// The established safety chain remains: recognize locally, parse on the server,
// and use full-image cloud OCR only after an actual local failure/empty result.
const localCall = client.indexOf('recognizeWithCoreVision(bytes)');
const lineParserCall = client.indexOf("requestSchedule('/api/schedule/parse'");
const imageFallbackCall = client.indexOf("requestSchedule(\n      '/api/schedule/ocr'");
assert.ok(localCall >= 0 && lineParserCall > localCall && imageFallbackCall > lineParserCall);
assert.match(client, /payload\.scheduleItems === undefined/);
assert.match(client, /payload\.scheduleItems\.length === 0/);

// A server-side macOS implementation detail must not be presented as a missing
// HarmonyOS package. The original error is still detected without claiming success.
assert.match(client, /serviceMessage\.includes\('本机 OCR 助手缺失'\)/);
assert.match(client, /云端备用识别暂不可用/);
assert.equal(index.includes("本机 Vision 备用识别"), false);
assert.ok(index.includes("云端备用识别"));

// Image parsing still has network permission and imported results still enter
// the existing review -> validation -> confirmed persistence flow.
assert.match(moduleProfile, /ohos\.permission\.INTERNET/);
assert.match(index, /this\.scheduleImportStatus = 'reviewing'/);
assert.match(index, /ScheduleEditingService\.prepare\(this\.scheduleDraftItems\)/);
assert.match(index, /this\.setupScheduleReady = true/);
assert.match(index, /this\.persistSilently\(\)/);

console.log('PASS schedule OCR release guard: Core Vision is packaged without a false short timeout; validation and persistence remain intact');
