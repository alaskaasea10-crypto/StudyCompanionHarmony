import { HvigorNode, HvigorPlugin } from '@ohos/hvigor';
import { appTasks, OhosPluginId } from '@ohos/hvigor-ohos-plugin';
import { existsSync, readFileSync } from 'fs';
import { resolve } from 'path';

interface LocalSigningOverride {
  signingConfig: {
    type: string;
    material: Record<string, string>;
  };
}

const localSigningPath = resolve(__dirname, '.signing', 'signing-config.local.json');
let localOverrides: LocalSigningOverride | undefined;

if (existsSync(localSigningPath)) {
  const localSigning = JSON.parse(readFileSync(localSigningPath, 'utf8')) as LocalSigningOverride;
  if (localSigning.signingConfig) {
    localOverrides = localSigning;
  }
}

const localSigningPlugin: HvigorPlugin = {
  pluginId: 'studycompanion-local-signing',
  apply(node: HvigorNode): void {
    if (!localOverrides) {
      return;
    }
    node.afterNodeEvaluate((evaluatedNode: HvigorNode) => {
      const context = evaluatedNode.getContext(OhosPluginId.OHOS_APP_PLUGIN);
      if (!context) {
        return;
      }
      const buildProfile = context.getBuildProfileOpt();
      buildProfile.app.signingConfigs = [{
        name: 'default',
        type: localOverrides!.signingConfig.type,
        material: localOverrides!.signingConfig.material
      }];
      context.setBuildProfileOpt(buildProfile);
    });
  }
};

export default {
  system: appTasks, /* Built-in plugin of Hvigor. It cannot be modified. */
  plugins: [localSigningPlugin] /* Local signing data is loaded only from an ignored file. */
}
