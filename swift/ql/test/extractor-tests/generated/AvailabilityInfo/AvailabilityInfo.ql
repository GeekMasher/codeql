// generated by codegen/codegen.py, do not edit
import codeql.swift.elements
import TestUtils

from AvailabilityInfo x, string isUnavailable, int getNumberOfSpecs
where
  toBeTested(x) and
  not x.isUnknown() and
  (if x.isUnavailable() then isUnavailable = "yes" else isUnavailable = "no") and
  getNumberOfSpecs = x.getNumberOfSpecs()
select x, "isUnavailable:", isUnavailable, "getNumberOfSpecs:", getNumberOfSpecs
