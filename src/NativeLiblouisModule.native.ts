// src/NativeLiblouisModule.native.ts
import type { NativeLiblouisModule } from './types';
const unavailable = () => { throw new Error('Native module not available'); };
const mod: NativeLiblouisModule = {
    lou_translateString: unavailable,
    lou_backTranslateString: unavailable,
    lou_isInitialized: unavailable,
};
export default mod;
