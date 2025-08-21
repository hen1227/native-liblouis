// src/index.ts
import NativeLiblouisModule from "./NativeLiblouisModule";

// export each individual function from the NativeLiblouisModule
export const {
  lou_translateString,
  lou_backTranslateString,
  lou_initialize,
  lou_isInitialized,
} = NativeLiblouisModule;

// Export the module itself for use in other parts of the application
export default NativeLiblouisModule;
