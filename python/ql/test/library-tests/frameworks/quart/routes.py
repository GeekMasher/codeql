from quart import Quart, request, make_response

app = Quart(__name__)

@app.route('/')
async def hello(): # $ requestHandler
    return 'hello'

@app.route("/safe")  # $routeSetup="/safe"
def safe():  # $requestHandler
    first_name = request.args.get('name', '')
    return make_response("Your name is " + escape(first_name))  # $HttpResponse

@app.route("/hello/<name>")  # $routeSetup="/hello/<name>"
def hello(name):  # $requestHandler routedParameter=name
    return make_response("Your name is " + name)  # $HttpResponse

@app.route("/foo/<path:subpath>")  # $routeSetup="/foo/<path:subpath>"
def foo(subpath):  # $requestHandler routedParameter=subpath
    return make_response("The subpath is " + subpath)  # $HttpResponse

@app.route("/multiple/")  # $routeSetup="/multiple/"
@app.route("/multiple/foo/<foo>")  # $routeSetup="/multiple/foo/<foo>"
@app.route("/multiple/bar/<bar>")  # $routeSetup="/multiple/bar/<bar>"
def multiple(foo=None, bar=None):  # $requestHandler routedParameter=foo routedParameter=bar
    return make_response("foo={!r} bar={!r}".format(foo, bar))  # $HttpResponse

@app.route("/complex/<string(length=2):lang_code>")  # $routeSetup="/complex/<string(length=2):lang_code>"
def complex(lang_code):  # $requestHandler routedParameter=lang_code
    return make_response("lang_code {}".format(lang_code))  # $HttpResponse
