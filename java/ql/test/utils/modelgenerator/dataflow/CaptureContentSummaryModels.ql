import java
import utils.modelgenerator.internal.CaptureModels
import SummaryModels
import utils.test.InlineMadTest

module InlineMadTestConfig implements InlineMadTestConfigSig {
  string getCapturedModel(Callable c) { result = ContentSensitive::captureFlow(c, _, _, _, _) }

  string getKind() { result = "contentbased-summary" }
}

import InlineMadTest<InlineMadTestConfig>
