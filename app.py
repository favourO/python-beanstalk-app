from flask import Flask

app = Flask(__name__)

@app.route('/')
def hello_world():
    return 'Hello, Demy data'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3000)