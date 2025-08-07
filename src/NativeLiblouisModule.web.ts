import { registerWebModule, NativeModule } from 'expo';

import { NativeLiblouisModuleEvents } from './NativeLiblouisModule.types';

class NativeLiblouisModule extends NativeModule<NativeLiblouisModuleEvents> {
  PI = Math.PI;
  async setValueAsync(value: string): Promise<void> {
    this.emit('onChange', { value });
  }
  hello() {
    return 'Hello world! 👋';
  }
}

export default registerWebModule(NativeLiblouisModule, 'NativeLiblouisModule');
