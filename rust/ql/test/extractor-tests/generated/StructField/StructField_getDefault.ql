// generated by codegen, do not edit
import codeql.rust.elements
import TestUtils

from StructField x
where toBeTested(x) and not x.isUnknown()
select x, x.getDefault()
