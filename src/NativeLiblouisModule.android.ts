// NativeLiblouisModule.android.ts
import { requireNativeModule } from "expo-modules-core";

import { NativeLiblouisModule } from "./types";

export default requireNativeModule<NativeLiblouisModule>(
  "NativeLiblouisModule",
);
