from quart import Quart, request

app = Quart(__name__)

@app.route('/')
async def hello(): # $ requestHandler
    ensure_tainted(
        # Arguments
        request.args["remote"], # $ tainted
        request.args.get("remote"), # $ tainted
        request.args.get("remote", "default"), # $ tainted
        # JSON
        request.get_json(),  # $ tainted
        # Headers
        request.headers["X-Remote"], # $ tainted
        request.headers.get("X-Remote"), # $ tainted
        # Cookies
        request.cookies["remote"], # $ tainted
        request.cookies.get("remote"), # $ tainted
        # Files
        request.files["remote"], # $ tainted
        request.files.get("remote"), # $ tainted
        # Form
        request.form["remote"], # $ tainted
        request.form.get("remote"), # $ tainted
    )

    return 'hello'

app.run()