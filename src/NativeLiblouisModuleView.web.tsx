import * as React from 'react';

import { NativeLiblouisModuleViewProps } from './NativeLiblouisModule.types';

export default function NativeLiblouisModuleView(props: NativeLiblouisModuleViewProps) {
  return (
    <div>
      <iframe
        style={{ flex: 1 }}
        src={props.url}
        onLoad={() => props.onLoad({ nativeEvent: { url: props.url } })}
      />
    </div>
  );
}
