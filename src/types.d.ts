// types.ts
export interface NativeLiblouisModule {
  /**
   * Translate text to braille
   * @param text The text to translate
   * @param table The braille table to use (e.g., "en-ueb-g2.ctb")
   * @returns The translated braille text
   */
  lou_translateString(text: string, table: string): string;

  /**
   * Back-translate braille to text
   * @param dots The ascii braille dots to back-translate
   * @param table The braille table to use
   * @returns The back-translated text
   */
  lou_backTranslateString(dots: string, table: string): string;

  /**
   * Initialize the module and load the necessary braille tables.
   * Required before using translate or backTranslate methods on Web.
   * <p>
   * This method is optional on native platforms, as the module is initialized automatically.
   */
  lou_initialize?: () => Promise<void>;

  /**
   * Check if the module is initialized.
   * @returns True if the module is initialized, false otherwise.
   */
  lou_isInitialized: () => boolean;
}

// Export type for the module
export type { NativeLiblouisModule as default };
