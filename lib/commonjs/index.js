"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.decodeOpus = decodeOpus;
exports.generateGuid = generateGuid;
var _reactNative = require("react-native");
var _reactNativeFs = _interopRequireDefault(require("react-native-fs"));
function _interopRequireDefault(e) { return e && e.__esModule ? e : { default: e }; }
const LINKING_ERROR = `The package 'react-native-opus-decode' doesn't seem to be linked. Make sure: \n\n` + _reactNative.Platform.select({
  ios: "- You have run 'pod install'\n",
  default: ''
}) + '- You rebuilt the app after installing the package\n' + '- You are not using Expo managed workflow\n';
const OpusDecode = _reactNative.NativeModules.OpusDecode ? _reactNative.NativeModules.OpusDecode : new Proxy({}, {
  get() {
    throw new Error(LINKING_ERROR);
  }
});
function generateGuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    // eslint-disable-next-line no-bitwise
    let r = Math.random() * 16 | 0,
      // eslint-disable-next-line no-bitwise
      v = c === 'x' ? r : r & 0x3 | 0x8;
    return v.toString(16);
  });
}
async function decodeOpus(sourceUri) {
  const guid = generateGuid();
  const sourcePath = `${_reactNativeFs.default.CachesDirectoryPath}/tmp-${guid}.opus`;
  const destPath = `${_reactNativeFs.default.CachesDirectoryPath}/tmp-${guid}.wav`;
  const downloadResult = _reactNativeFs.default.downloadFile({
    fromUrl: sourceUri,
    toFile: sourcePath
  });
  await downloadResult.promise;
  return OpusDecode.decodeFromUri(sourcePath, destPath);
}
//# sourceMappingURL=index.js.map