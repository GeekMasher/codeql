/**
 * Provides classes modeling security-relevant aspects of the `quart` PyPI package.
 * See https://quart.palletsprojects.com/en/latest/ .
 */

private import python
private import semmle.python.dataflow.new.DataFlow
private import semmle.python.dataflow.new.RemoteFlowSources
private import semmle.python.dataflow.new.TaintTracking
private import semmle.python.Concepts
private import semmle.python.frameworks.Werkzeug
private import semmle.python.frameworks.Stdlib
private import semmle.python.ApiGraphs
private import semmle.python.frameworks.internal.InstanceTaintStepsHelper
private import semmle.python.security.dataflow.PathInjectionCustomizations
private import semmle.python.dataflow.new.FlowSummary
private import semmle.python.frameworks.data.ModelsAsData

/**
 * Provides models for the `quart` PyPI package.
 * See https://quart.palletsprojects.com/en/1.1.x/.
 */
module Quart {
  module QuartApp {
    /** Gets a reference to the `quart.Quart` class. */
    API::Node classRef() {
      result = API::moduleImport("quart").getMember("Quart") or
      result = ModelOutput::getATypeNode("quart.Quart~Subclass").getASubclass*()
    }

    /** Gets a reference to an instance of `quart.Quart` (a quart application). */
    API::Node instance() { result = classRef().getReturn() }
  }

  /** Gets a reference to the `quart.request` object. */
  API::Node request() { result = API::moduleImport("quart").getMember("request") }

  abstract class QuartRouteSetup extends Http::Server::RouteSetup::Range {
    override Parameter getARoutedParameter() { result = this.getARequestHandler().getKwarg() }

    override string getFramework() { result = "Quart" }
  }

  /**
   * Quart route setup using `quart.Quart.route`.
   */
  private class QuartAppRouteCall extends QuartRouteSetup, DataFlow::CallCfgNode {
    QuartAppRouteCall() { this = QuartApp::instance().getMember("route").getACall() }

    override DataFlow::Node getUrlPatternArg() {
      result in [this.getArg(0), this.getArgByName("rule")]
    }

    override Function getARequestHandler() { result.getADecorator().getAFlowNode() = node }
  }

  module Response {
    API::Node classRef() {
      result = API::moduleImport("quart").getMember("Response")
      or
      result = [QuartApp::classRef(), QuartApp::instance()].getMember("response_class")
      or
      result = ModelOutput::getATypeNode("quart.Response~Subclass").getASubclass*()
    }

    abstract class InstanceSource extends Http::Server::HttpResponse::Range, DataFlow::Node { }

    private class QuarkMakeResponseCall extends InstanceSource, DataFlow::CallCfgNode {
      QuarkMakeResponseCall() {
        this = API::moduleImport("quart").getMember("make_response").getACall()
        or
        this = QuartApp::instance().getMember("make_response").getACall()
      }

      override DataFlow::Node getBody() { result = this.getArg(0) }

      override string getMimetypeDefault() { result = "text/html" }

      override DataFlow::Node getMimetypeOrContentTypeArg() { none() }
    }
  }
}
