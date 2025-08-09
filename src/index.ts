import { Platform } from 'react-native';
import {NativeLiblouisModule} from "./types";

let module: NativeLiblouisModule = {
    lou_translateString: (text: string, table: string): string => {
        throw new Error('Native module not available');
    },
    lou_backTranslateString: (dots: string, table: string): string => {
        throw new Error('Native module not available');
    },
    lou_isInitialized: (): boolean => {
        throw new Error('Native module not available');
    },
}

if (Platform.OS === 'web') {
    module = require('./NativeLiblouisModule.web').default;
} else if (Platform.OS === 'ios') {
    module = require('./NativeLiblouisModule.ios').default;
} else if (Platform.OS === 'android') {
    module = require('./NativeLiblouisModule.android').default;
}

export default module;
