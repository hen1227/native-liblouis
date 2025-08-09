// Built liblouis WebAssembly file is .js, so no type definitions are available.
// @ts-ignore
import LibLouisFactory from './liblouis-web/liblouis.js';

let lib: any = null;
let initialized = false;
let initializationError: Error | null = null;

const BUNDLED_TABLES_DIR = 'tables';

/**
 * Initializes the LibLouis WebAssembly module and verifies required table files.
 * Must be called before any translation is performed.
 */
const lou_initialize = async (): Promise<boolean> => {
    if (initialized && lib) return true;

    // Reset state
    initialized = false;
    initializationError = null;

    try {
        lib = await LibLouisFactory();

        if (!lib || !lib.FS) {
            throw new Error('Failed to load LibLouis or missing FS interface');
        }

        // Attempt to set log level if available (non-fatal)
        try {
            lib.ccall('lou_setLogLevel', 'number', ['number'], [40000]); // LOU_LOG_ERROR
        } catch (_) {
            // Ignore if not available
        }

        initialized = true;
        return true;
    } catch (error: any) {
        initializationError = error;
        lib = null;
        initialized = false;
        throw error;
    }
};

/**
 * Translates plain text into Braille using specified tables.
 * @param text Input string
 * @param tables Comma-separated table names
 */
const lou_translateString = (text: string, tables: string): string => {
    ensureInitialized();
    const tablePath = resolveTablePath(tables);
    return runTranslation(text, tablePath, 'lou_translateString');
};

/**
 * Translates Braille dots into plain text using specified tables.
 * @param dots Braille dots as string
 * @param tables Comma-separated table names
 */
const lou_backTranslateString = (dots: string, tables: string): string => {
    ensureInitialized();
    const tablePath = resolveTablePath(tables);
    return runTranslation(dots, tablePath, 'lou_backTranslateString');
};

const lou_isInitialized = (): boolean => {
    return initialized;
}

/**
 * Throws an error if the module is not initialized
 */
const ensureInitialized = () => {
    if (!initialized || !lib) {
        throw initializationError ??
        new Error('LibLouis not initialized. Call initialize() first and await it.');
    }
};

/**
 * Builds full paths for table names
 */
const resolveTablePath = (tables: string): string =>
    tables.split(',').map(t => `/${BUNDLED_TABLES_DIR}/${t}`).join(',');

/**
 * Handles memory allocation and performs the actual translation call
 */
const runTranslation = (input: string, tablePath: string, fnName: string): string => {
    const inLen = input.length;
    const maxOutChars = inLen * 10;

    const inLenPtr = lib._malloc(4);
    const outLenPtr = lib._malloc(4);
    const inBufPtr = lib._malloc((inLen + 1) * 2);
    const outBufPtr = lib._malloc((maxOutChars + 1) * 2);
    const tablePtr = lib.allocateUTF8(tablePath);

    try {
        lib.setValue(inLenPtr, inLen, 'i32');
        lib.setValue(outLenPtr, maxOutChars, 'i32');

        // Write UTF-16 input string
        for (let i = 0; i < inLen; i++) {
            lib.setValue(inBufPtr + i * 2, input.charCodeAt(i), 'i16');
        }
        lib.setValue(inBufPtr + inLen * 2, 0, 'i16'); // null-terminator

        const success = lib.ccall(
            fnName,
            'number',
            ['number', 'number', 'number', 'number', 'number', 'number', 'number', 'number'],
            [tablePtr, inBufPtr, inLenPtr, outBufPtr, outLenPtr, 0, 0, 0]
        );

        if (!success) {
            throw new Error(`${fnName} failed for input: "${input}"`);
        }

        const actualOutLen = lib.getValue(outLenPtr, 'i32');
        let result = '';
        for (let i = 0; i < actualOutLen; i++) {
            result += String.fromCharCode(lib.getValue(outBufPtr + i * 2, 'i16'));
        }
        return result;
    } finally {
        lib._free(tablePtr);
        lib._free(inBufPtr);
        lib._free(outBufPtr);
        lib._free(inLenPtr);
        lib._free(outLenPtr);
    }
};

export default {
    lou_translateString,
    lou_backTranslateString,
    lou_initialize,
    lou_isInitialized
};
