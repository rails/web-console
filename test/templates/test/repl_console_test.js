suite('REPLConsole', function() {
  suiteSetup(function() {
    this.stage = document.createElement('div');
    document.body.appendChild(this.stage);
  });

  setup(function() {
    var elm = document.createElement('div');
    elm.innerHTML = '<div id="console"></div>';
    this.stage.appendChild(elm);
    var consoleOptions = { mountPoint: '/mock', sessionId: 'result' };
    this.console = REPLConsole.installInto('console', consoleOptions);
  });

  teardown(function() { removeAllChildren(this.stage); });

  suite('REPLConsole.installInto()', function() {
    setup(function() {
      var elm = document.createElement('div');
      elm.innerHTML = '<div id="my-console" ' +
        'data-mount-point="my-mount-point" ' +
        'data-session-id="my-session-id" ' +
        'data-prompt-label="my-prompt-label" ' +
        '></div>';
      this.stage.appendChild(elm);
    });

    test('console can be installed with dataset', function() {
      var console = REPLConsole.installInto('my-console');
      assert.equal('my-prompt-label', console.prompt);
      assert.equal('my-mount-point',  console.mountPoint);
      assert.equal('my-session-id',   console.sessionId);
    });

    test('console can be installed with argument options', function() {
      var options = { mountPoint: 'other-mount-point', sessionId: 'other-session-id' };
      var console = REPLConsole.installInto('my-console', options);
      assert.equal('other-mount-point', console.mountPoint);
      assert.equal('other-session-id', console.sessionId);
      assert.equal('my-prompt-label', console.prompt);
    });
  });

  suite('Installing', function() {
    test('#install renders console into an element', function() {
      var div = document.createElement('div');
      var console = new REPLConsole;
      console.install(div);
      assert.equal(1, div.getElementsByClassName('console-inner').length);
      assert.equal(1, div.getElementsByClassName('resizer').length);
      assert.equal(1, div.getElementsByClassName('close-button').length);
    });
  });

  suite('Actions', function() {
    test('close button removes console on clicked', function() {
      var div = document.createElement('div');
      div.id = 'my-console';
      this.stage.appendChild(div);
      REPLConsole.installInto('my-console');
      assert.isNotNull(document.getElementById('my-console'));

      var btn = div.getElementsByClassName('close-button')[0];
      TestHelper.triggerEvent(btn, 'click');

      assert.isNull(document.getElementById('my-console'));
    });
  });

  suite('Command Handling', function() {
    test('#commandHandle renders output to console', function(done) {
      var inner = this.console.inner;
      this.console.commandHandle('fake-input', function(result, response) {
        var msg = inner.getElementsByClassName('console-message')[0];

        assert.ok(result);
        assert.match(msg.innerText, /"fake-result"/);
        assert.notOk(hasClass(msg, 'error-message'));

        done();
      });
    });

    test('#commandHandle shows error message if something is wrong', function(done) {
      var inner = this.console.inner;
      this.console.sessionId = 'error';
      this.console.commandHandle('fake-input', function(result, response) {
        var msg = inner.getElementsByClassName('console-message')[0];

        assert.notOk(result);
        assert.match(msg.innerText, /fake-error-message/);
        assert.ok(hasClass(msg, 'error-message'));

        done();
      });
    });

    test('#commandHandle shows HTTP status code if something is wrong', function(done) {
      var inner = this.console.inner;
      this.console.sessionId = 'error.txt';
      this.console.commandHandle('fake-input', function(result, response) {
        var msg = inner.getElementsByClassName('console-message')[0];

        assert.notOk(result);
        assert.match(msg.innerText, /400 Bad Request/);

        done();
      });
    });
  });

  suite('Auto Completion', function() {
    test('swap last word', function() {
      this.console.setInput('hello world');
      this.console.swapCurrentWord('word');

      assert.equal(this.console._input, 'hello word');
    });

    test('swap first word', function() {
      this.console.setInput('hello world');
      this.console._caretPos = 0;
      this.console.swapCurrentWord('my');

      assert.equal(this.console._input, 'my world');
    });

    test('current word', function() {
      this.console.setInput('hello world');
      assert.equal(this.console.getCurrentWord(), 'world');
      this.console._caretPos = 0;
      assert.equal(this.console.getCurrentWord(), 'hello');
      this.console._caretPos = 5;
      assert.equal(this.console.getCurrentWord(), '');
      this.console._caretPos = 6;
      assert.equal(this.console.getCurrentWord(), 'world');
    });

    test('console can start auto completion by typing tab key', function(done) {
      this.console.setInput('some');
      assert.notOk(this.console.autocomplete);
      this.console.onKeyDown(TestHelper.keyDown(9)); // tab
      assert.ok(this.console.autocomplete);

      var self = this;
      setTimeout(function() {
        self.console.autocomplete.onFinished(function(word) {
          assert.equal('something', word);
          done();
        });
        self.console.onKeyDown(TestHelper.keyDown(TestHelper.KEY_TAB));
        self.console.onKeyDown(TestHelper.keyDown(TestHelper.KEY_ENTER));
      }, 100);
    });
  });

  suite('Auto Suggestion', function() {
    test('shows first matched word in current context', function(done) {
      var c = this.console;
      c.setInput('some');
      setTimeout(function() {
        assert.match(c.promptDisplay.innerText, /^something/);
        done();
      }, 100);
    });

    test('hides automatically in a few seconds', function(done) {
      var c = this.console;
      c.suggestWait = 200;
      c.setInput('some');

      assert.equal('some\u00A0', c.promptDisplay.innerText);
      setTimeout(function() {
        assert.match(c.promptDisplay.innerText, /something/);
        setTimeout(function() {
          assert.equal('some\u00A0', c.promptDisplay.innerText);
          done();
        }, 200);
      }, 100);
    });

    test('inserts the current word if tab key is pressed', function(done) {
      var c = this.console;
      c.setInput('some');

      setTimeout(function() {
        c.onKeyDown(TestHelper.keyDown(TestHelper.KEY_TAB));
        assert.equal('something', c._input);
        done();
      }, 100);
    });
  });
});
