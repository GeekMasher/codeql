private import codeql.swift.generated.Comment

module Impl {
  class Comment extends Generated::Comment {
    /** toString */
    override string toStringImpl() { result = this.getText() }
  }
}
