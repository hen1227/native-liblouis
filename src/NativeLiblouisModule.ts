import { NativeModule, requireNativeModule } from 'expo';

import { NativeLiblouisModuleEvents } from './NativeLiblouisModule.types';

declare class NativeLiblouisModule extends NativeModule<NativeLiblouisModuleEvents> {
  PI: number;
  hello(): string;
  setValueAsync(value: string): Promise<void>;
}

// This call loads the native module object from the JSI.
export default requireNativeModule<NativeLiblouisModule>('NativeLiblouisModule');
