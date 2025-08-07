import { requireNativeView } from 'expo';
import * as React from 'react';

import { NativeLiblouisModuleViewProps } from './NativeLiblouisModule.types';

const NativeView: React.ComponentType<NativeLiblouisModuleViewProps> =
  requireNativeView('NativeLiblouisModule');

export default function NativeLiblouisModuleView(props: NativeLiblouisModuleViewProps) {
  return <NativeView {...props} />;
}
