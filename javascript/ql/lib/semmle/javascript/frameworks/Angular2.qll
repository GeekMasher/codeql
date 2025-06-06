/**
 * Provides classes for working with Angular (also known as Angular 2.x) applications.
 */

private import javascript
private import semmle.javascript.security.dataflow.DomBasedXssCustomizations
private import semmle.javascript.security.dataflow.CodeInjectionCustomizations
private import semmle.javascript.security.dataflow.ClientSideUrlRedirectCustomizations
private import semmle.javascript.DynamicPropertyAccess
private import semmle.javascript.dataflow.internal.PreCallGraphStep
private import semmle.javascript.ViewComponentInput
private import semmle.javascript.internal.paths.PathExprResolver

/**
 * Provides classes for working with Angular (also known as Angular 2.x) applications.
 */
module Angular2 {
  /** Gets a reference to a `Router` object. */
  DataFlow::SourceNode router() { result.hasUnderlyingType("@angular/router", "Router") }

  /** Gets a reference to a `RouterState` object. */
  DataFlow::SourceNode routerState() {
    result.hasUnderlyingType("@angular/router", "RouterState")
    or
    result = router().getAPropertyRead("routerState")
  }

  /** Gets a reference to a `RouterStateSnapshot` object. */
  DataFlow::SourceNode routerStateSnapshot() {
    result.hasUnderlyingType("@angular/router", "RouterStateSnapshot")
    or
    result = routerState().getAPropertyRead("snapshot")
  }

  /** Gets a reference to an `ActivatedRoute` object. */
  DataFlow::SourceNode activatedRoute() {
    result.hasUnderlyingType("@angular/router", "ActivatedRoute")
  }

  /** Gets a reference to an `ActivatedRouteSnapshot` object. */
  DataFlow::SourceNode activatedRouteSnapshot() {
    result.hasUnderlyingType("@angular/router", "ActivatedRouteSnapshot")
    or
    result = activatedRoute().getAPropertyRead("snapshot")
  }

  /**
   * Gets a data flow node referring to the value of the route property `name`, accessed
   * via one of the following patterns:
   * ```js
   * route.snapshot.name
   * route.snapshot.data.name
   * route.name.subscribe(x => ...)
   * ```
   */
  DataFlow::SourceNode activatedRouteProp(string name) {
    // this.route.snapshot.foo
    result = activatedRouteSnapshot().getAPropertyRead(name)
    or
    // this.route.snapshot.data.foo
    result = activatedRouteSnapshot().getAPropertyRead("data").getAPropertyRead(name)
    or
    // this.route.foo.subscribe(foo => { ... })
    result =
      activatedRoute()
          .getAPropertyRead(name)
          .getAMethodCall("subscribe")
          .getABoundCallbackParameter(0, 0)
  }

  /** Gets an array of URL segments matched by some route. */
  private DataFlow::SourceNode urlSegmentArray() { result = activatedRouteProp("url") }

  /** Gets a data flow node referring to a `UrlSegment` object matched by some route. */
  DataFlow::SourceNode urlSegment() {
    result = getAnEnumeratedArrayElement(urlSegmentArray())
    or
    result = urlSegmentArray().getAPropertyRead(any(string s | exists(s.toInt())))
  }

  /** Gets a reference to a `ParamMap` object, usually containing values from the URL. */
  private DataFlow::SourceNode paramMap(ClientSideRemoteFlowKind kind) {
    result.hasUnderlyingType("@angular/router", "ParamMap") and kind.isPath()
    or
    result = activatedRouteProp("paramMap") and kind.isPath()
    or
    result = activatedRouteProp("queryParamMap") and kind.isQuery()
    or
    result = urlSegment().getAPropertyRead("parameterMap") and kind.isPath()
  }

  /** Gets a reference to a `ParamMap` object, usually containing values from the URL. */
  DataFlow::SourceNode paramMap() { result = paramMap(_) }

  /** Gets a reference to a `Params` object, usually containing values from the URL. */
  private DataFlow::SourceNode paramDictionaryObject(ClientSideRemoteFlowKind kind) {
    result.hasUnderlyingType("@angular/router", "Params") and
    kind.isPath() and
    not result instanceof DataFlow::ObjectLiteralNode // ignore object literals found by contextual typing
    or
    result = activatedRouteProp("params") and kind.isPath()
    or
    result = activatedRouteProp("queryParams") and kind.isQuery()
    or
    result = paramMap(kind).getAPropertyRead("params")
    or
    result = urlSegment().getAPropertyRead("parameters") and kind.isPath()
  }

  /** Gets a reference to a `Params` object, usually containing values from the URL. */
  DataFlow::SourceNode paramDictionaryObject() { result = paramDictionaryObject(_) }

  /**
   * A value from `@angular/router` derived from the URL.
   */
  class AngularSource extends ClientSideRemoteFlowSource {
    ClientSideRemoteFlowKind kind;

    AngularSource() {
      this = paramMap(kind).getAMethodCall(["get", "getAll"])
      or
      this = paramDictionaryObject(kind)
      or
      this = activatedRouteProp("fragment") and kind.isFragment()
      or
      this = urlSegment().getAPropertyRead("path") and kind.isPath()
      or
      // Note that Router.url and RouterStateSnapshot.url are strings, not UrlSegment[]
      this = router().getAPropertyRead("url") and kind.isUrl()
      or
      this = routerStateSnapshot().getAPropertyRead("url") and kind.isUrl()
    }

    override string getSourceType() { result = "Angular route parameter" }

    override ClientSideRemoteFlowKind getKind() { result = kind }
  }

  /** Gets a reference to a `DomSanitizer` object. */
  DataFlow::SourceNode domSanitizer() {
    result.hasUnderlyingType(["@angular/platform-browser", "@angular/core"], "DomSanitizer")
  }

  /** A value that is about to be promoted to a trusted HTML or CSS value. */
  private class AngularXssSink extends DomBasedXss::Sink {
    AngularXssSink() {
      this =
        domSanitizer()
            .getAMethodCall(["bypassSecurityTrustHtml", "bypassSecurityTrustStyle"])
            .getArgument(0)
    }
  }

  /** A value that is about to be promoted to a trusted script value. */
  private class AngularCodeInjectionSink extends CodeInjection::Sink {
    AngularCodeInjectionSink() {
      this = domSanitizer().getAMethodCall("bypassSecurityTrustScript").getArgument(0)
    }
  }

  /**
   * A value that is about to be promoted to a trusted URL or resource URL value.
   */
  private class AngularUrlSink extends ClientSideUrlRedirect::Sink {
    // We mark this as a client URL redirect sink for precision reasons, though its description can be a bit confusing.
    AngularUrlSink() {
      this =
        domSanitizer()
            .getAMethodCall(["bypassSecurityTrustUrl", "bypassSecurityTrustResourceUrl"])
            .getArgument(0)
    }
  }

  private predicate taintStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(DataFlow::CallNode call |
      call = DataFlow::moduleMember("@angular/router", "convertToParamMap").getACall()
      or
      call = router().getAMemberCall(["parseUrl", "serializeUrl"])
    |
      pred = call.getArgument(0) and
      succ = call
    )
  }

  private class AngularTaintStep extends TaintTracking::SharedTaintStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) { taintStep(pred, succ) }
  }

  /** Gets a reference to an `HttpClient` object. */
  DataFlow::SourceNode httpClient() {
    result.hasUnderlyingType("@angular/common/http", "HttpClient")
  }

  /** Gets a reference to an `HttpClient` object using the API graph. */
  API::Node httpClientApiNode() { result = API::Node::ofType("@angular/common/http", "HttpClient") }

  private class AngularClientRequest extends ClientRequest::Range, DataFlow::MethodCallNode {
    int argumentOffset;

    AngularClientRequest() {
      this = httpClientApiNode().getMember("request").getACall() and argumentOffset = 1
      or
      this = httpClientApiNode().getAMember().getACall() and
      not this.getMethodName() = "request" and
      argumentOffset = 0
    }

    override DataFlow::Node getUrl() { result = this.getArgument(argumentOffset) }

    override DataFlow::Node getHost() { none() }

    override DataFlow::Node getADataNode() {
      this.getMethodName() = ["patch", "post", "put"] and
      result = this.getArgument(argumentOffset + 1)
      or
      result = this.getOptionArgument(argumentOffset + 1, "body")
    }

    override DataFlow::Node getAResponseDataNode(string responseType, boolean promise) {
      result = this and responseType = "rxjs.observable" and promise = false
    }
  }

  /** Gets a reference to a `DomAdapter`, which provides acess to raw DOM elements. */
  private DataFlow::SourceNode domAdapter() {
    // Note: these are internal properties, prefixed with the "latin small letter barred O (U+0275)" character.
    // Despite being internal, some codebases do access them.
    result.hasUnderlyingType("@angular/common", 629.toUnicode() + "DomAdapter")
    or
    result = DataFlow::moduleImport("@angular/common").getAMemberCall(629.toUnicode() + "getDOM")
  }

  /** A reference to the DOM location obtained through `DomAdapter.getLocation()`. */
  private class DomAdapterLocation extends DOM::LocationSource::Range {
    DomAdapterLocation() { this = domAdapter().getAMethodCall("getLocation") }
  }

  class PipeRefExpr = Templating::PipeRefExpr;

  class TemplateVarRefExpr = Templating::TemplateVarRefExpr;

  class TemplateTopLevel = Templating::TemplateTopLevel;

  private predicate shouldResolveExpr(Expr e) {
    exists(Property prop |
      prop.getName() = "templateUrl" and
      e = prop.getInit()
    )
  }

  private module Resolver = ResolveExpr<shouldResolveExpr/1>;

  /**
   * Holds if the value of `attrib` is interpreted as an Angular expression.
   */
  predicate isAngularExpressionAttribute(HTML::Attribute attrib) {
    attrib.getName().matches("(%)") or
    attrib.getName().matches("[%]") or
    attrib.getName().matches("*ng%")
  }

  private DataFlow::Node getAttributeValueAsNode(HTML::Attribute attrib) {
    result = attrib.getCodeInAttribute().(TemplateTopLevel).getExpression().flow()
  }

  /**
   * The class for an Angular component.
   */
  class ComponentClass extends DataFlow::ClassNode {
    DataFlow::CallNode decorator;

    ComponentClass() {
      decorator = this.getADecorator() and
      decorator = DataFlow::moduleMember("@angular/core", "Component").getACall()
    }

    /**
     * Gets a data flow node representing the value of the declared
     * instance field of the given name.
     */
    DataFlow::Node getFieldNode(string name) {
      exists(FieldDeclaration f |
        f.getName() = name and
        f.getDeclaringClass().flow() = this and
        result = DataFlow::fieldDeclarationNode(f)
      )
    }

    /**
     * Gets a data flow node representing data flowing into a field of
     * this component.
     */
    DataFlow::Node getFieldInputNode(string name) {
      result = this.getFieldNode(name)
      or
      result = this.getInstanceMember(name, DataFlow::MemberKind::setter()).getParameter(0)
    }

    /**
     * Gets a data flow node representing data flowing out of a field
     * of this component.
     */
    DataFlow::Node getFieldOutputNode(string name) {
      result = this.getFieldNode(name)
      or
      result = this.getInstanceMember(name, DataFlow::MemberKind::getter()).getReturnNode()
      or
      result = this.getInstanceMethod(name)
    }

    /**
     * Gets the `selector` property of the `@Component` decorator.
     */
    string getSelector() { decorator.getOptionArgument(0, "selector").mayHaveStringValue(result) }

    /** Gets an HTML element that instantiates this component. */
    HTML::Element getATemplateInstantiation() { result.getName() = this.getSelector() }

    /**
     * Gets an argument that flows into the `name` field of this component.
     *
     * For example, if the selector for this component is `"my-class"`, then this
     * predicate can match an attribute like: `<my-class [foo]="1+2"/>`.
     * The result of this predicate would be the `1+2` expression, and `name` would be `"foo"`.
     */
    DataFlow::Node getATemplateArgument(string name) {
      result =
        getAttributeValueAsNode(this.getATemplateInstantiation()
              .getAttributeByName("[" + name + "]"))
    }

    /**
     * Gets the file referred to by `templateUrl`.
     *
     * Has no result if the template is given inline via a `template` property.
     */
    pragma[noinline]
    File getTemplateFile() {
      result = Resolver::resolveExpr(decorator.getOptionArgument(0, "templateUrl").asExpr())
    }

    /** Gets an element in the HTML template of this component. */
    HTML::Element getATemplateElement() {
      result.getFile() = this.getTemplateFile()
      or
      result.getParent*() =
        HTML::getHtmlElementFromExpr(decorator.getOptionArgument(0, "template").asExpr(), _)
    }

    /**
     * Gets an access to the given template variable within the template body of this component.
     */
    DataFlow::SourceNode getATemplateVarAccess(string name) {
      result =
        this.getATemplateElement()
            .getAnAttribute()
            .getCodeInAttribute()
            .(TemplateTopLevel)
            .getAVariableUse(name)
    }
  }

  /** A class with the `@Pipe` decorator. */
  class PipeClass extends DataFlow::ClassNode {
    DataFlow::CallNode decorator;

    PipeClass() {
      decorator = DataFlow::moduleMember("@angular/core", "Pipe").getACall() and
      decorator = this.getADecorator()
    }

    /** Gets the value of the `name` option passed to the `@Pipe` decorator. */
    string getPipeName() { decorator.getOptionArgument(0, "name").mayHaveStringValue(result) }

    /** Gets a reference to this pipe. */
    DataFlow::Node getAPipeRef() { result.asExpr().(PipeRefExpr).getName() = this.getPipeName() }
  }

  private class ComponentSteps extends PreCallGraphStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(ComponentClass cls, string name |
        // From <my-class [foo]="bar"/> to `foo` field in class
        pred = cls.getATemplateArgument(name) and
        succ = cls.getFieldInputNode(name)
        or
        // From `foo` field in class to <other-component [baz]="foo"/>
        pred = cls.getFieldOutputNode(name) and
        succ = cls.getATemplateVarAccess(name)
        or
        // From property write to the field input node
        pred = cls.getAReceiverNode().getAPropertyWrite(name).getRhs() and
        succ = cls.getFieldInputNode(name)
        or
        // From the field node to property read.
        // We use `getFieldNode` instead of `getFieldOutputNode` as the other two cases
        // from `getFieldOutputNode` are already handled by the general data flow library.
        pred = cls.getFieldNode(name) and
        succ = cls.getAReceiverNode().getAPropertyRead(name)
      )
    }
  }

  private class PipeSteps extends PreCallGraphStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(PipeClass cls |
        pred = cls.getInstanceMethod("transform") and
        succ = cls.getAPipeRef()
      )
    }
  }

  /**
   * An attribute of form `*ngFor="let var of EXPR"`.
   *
   * The `EXPR` has been extracted as the sole `CodeInAttribute` top-level for this
   * attribute. There is no AST node for the implied for-of loop.
   */
  private class ForLoopAttribute extends HTML::Attribute {
    ForLoopAttribute() { this.getName() = "*ngFor" }

    /** Gets a data-flow node holding the value being iterated over. */
    DataFlow::Node getIterationDomain() { result = getAttributeValueAsNode(this) }

    /** Gets the name of the variable holding the element of the current iteration. */
    string getIteratorName() { result = this.getValue().regexpCapture(" *let +(\\w+).*", 1) }

    /** Gets an HTML element in which the iterator variable is in scope. */
    HTML::Element getAnElementInScope() { result.getParent*() = this.getElement() }

    /** Gets a reference to the iterator variable. */
    DataFlow::Node getAnIteratorAccess() {
      result =
        this.getAnElementInScope()
            .getAnAttribute()
            .getCodeInAttribute()
            .(TemplateTopLevel)
            .getAVariableUse(this.getIteratorName())
    }
  }

  /**
   * A taint step `array -> elem` in `*ngFor="let elem of array"`, or more precisely,
   * a step from `array` to each access to `elem`.
   */
  private class ForLoopStep extends TaintTracking::SharedTaintStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(ForLoopAttribute attrib |
        pred = attrib.getIterationDomain() and
        succ = attrib.getAnIteratorAccess()
      )
    }
  }

  private class AnyCastStep extends PreCallGraphStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(DataFlow::CallNode call |
        call = any(TemplateTopLevel tl).getAVariableUse("$any").getACall() and
        pred = call.getArgument(0) and
        succ = call
      )
    }
  }

  private class BuiltinPipeStep extends TaintTracking::SharedTaintStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(DataFlow::CallNode call, string name |
        call = Templating::getAPipeCall(name) and
        succ = call
      |
        exists(int i | pred = call.getArgument(i) |
          i = 0 and
          name =
            [
              "async", "i18nPlural", "json", "keyvalue", "lowercase", "uppercase", "titlecase",
              "slice"
            ]
          or
          i = 1 and name = "date" // date format string
        )
        or
        name = "translate" and
        pred = [call.getArgument(1), call.getOptionArgument(1, _)]
      )
    }
  }

  /**
   * A `<mat-table>` element.
   */
  class MatTableElement extends HTML::Element {
    MatTableElement() { this.getName() = "mat-table" }

    /** Gets the data flow node corresponding to the `[dataSource]` attribute. */
    DataFlow::Node getDataSourceNode() {
      result = getAttributeValueAsNode(this.getAttributeByName("[dataSource]"))
    }

    /**
     * Gets an element of form `<mat-cell *matCellDef="let rowBinding">` in this table.
     */
    HTML::Element getATableCell(string rowBinding) {
      result.getName() = "mat-cell" and
      result.getParent+() = this and
      rowBinding =
        result.getAttributeByName("*matCellDef").getValue().regexpCapture(" *let +(\\w+).*", 1)
    }

    /** Gets a data flow node that refers to one of the rows from the data source. */
    DataFlow::Node getARowRef() {
      exists(string rowBinding |
        result =
          this.getATableCell(rowBinding)
              .getChild*()
              .getAnAttribute()
              .getCodeInAttribute()
              .(TemplateTopLevel)
              .getAVariableUse(rowBinding)
      )
    }
  }

  /**
   * A taint step from `x -> y` in code of form:
   * ```
   * <mat-table [dataSource]="x">
   *   <mat-cell *matCellDef="let y">
   *     <foo [prop]="y"/>
   *   </mat-cell>
   * </mat-table>
   * ```
   */
  private class MatTableTaintStep extends TaintTracking::SharedTaintStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(MatTableElement table |
        pred = table.getDataSourceNode() and
        succ = table.getARowRef()
      )
    }
  }

  /** A taint step into the data array of a `MatTableDataSource` instance. */
  private class MatTableDataSourceStep extends TaintTracking::SharedTaintStep {
    override predicate step(DataFlow::Node pred, DataFlow::Node succ) {
      exists(DataFlow::NewNode invoke |
        invoke =
          DataFlow::moduleMember("@angular/material/table", "MatTableDataSource")
              .getAnInstantiation() and
        pred = [invoke.getArgument(0), invoke.getAPropertyWrite("data").getRhs()] and
        succ = invoke
      )
    }
  }

  private class DomValueSources extends DOM::DomValueSource::Range {
    DomValueSources() {
      this = API::Node::ofType("@angular/core", "ElementRef").getMember("nativeElement").asSource()
    }
  }

  /**
   * A DOM attribute write, using the AngularJS Renderer2 API: a call to `Renderer2.setProperty`.
   */
  class AngularRenderer2AttributeDefinition extends DOM::AttributeDefinition {
    DataFlow::Node propertyNode;
    DataFlow::Node valueNode;
    DataFlow::Node elementNode;

    AngularRenderer2AttributeDefinition() {
      exists(API::CallNode setProperty |
        setProperty =
          API::moduleImport("@angular/core")
              .getMember("Renderer2")
              .getInstance()
              .getMember("setProperty")
              .getACall() and
        elementNode = setProperty.getArgument(0) and
        propertyNode = setProperty.getArgument(1) and
        valueNode = setProperty.getArgument(2) and
        this = setProperty.asExpr()
      )
    }

    override string getName() { result = propertyNode.getStringValue() }

    /**
     * Get the `DataFlow::Node` that is affected by this Attribute Definition.
     *
     *  Defined instead of defining `getElement()`, which requires returning a DOM element definition, `ElementDefinition`.
     */
    DataFlow::Node getElementNode() { result = elementNode }

    override DataFlow::Node getValueNode() { result = valueNode }
  }

  /**
   * A source of DOM events originating from the `$event` variable in an event handler installed in an Angular template.
   */
  private class DomEventSources extends DOM::DomEventSource::Range {
    DomEventSources() {
      exists(HTML::Element elm, string attributeName |
        elm = any(ComponentClass cls).getATemplateElement() and
        // Ignore instantiations of known element (mainly focus on native DOM elements)
        not elm = any(ComponentClass cls).getATemplateInstantiation() and
        not elm.getName().matches("ng-%") and
        this =
          elm.getAttributeByName(attributeName)
              .getCodeInAttribute()
              .(TemplateTopLevel)
              .getAVariableUse("$event") and
        attributeName.matches("(%)") and // event handler attribute
        not attributeName.matches("(ng%)") // exclude NG events which aren't necessarily DOM events
      )
    }
  }

  private class InputFieldAsViewComponentInput extends ViewComponentInput {
    InputFieldAsViewComponentInput() {
      this =
        API::moduleImport("@angular/core")
            .getMember("Input")
            .getReturn()
            .getADecoratedMember()
            .asSource()
    }

    override string getSourceType() { result = "Angular component input field" }
  }
}
