(function() {
  'use strict';

  function FakeKeyEvent(key) {
    this.keyCode = key;
    this.preventDefault = function() {};
    this.stopPropagation = function() {};
  }

  var TestHelper = {
    triggerEvent: function(el, eventName) {
      var event = document.createEvent("MouseEvents");
      event.initEvent(eventName, true, true); // type, bubbles, cancelable
      el.dispatchEvent(event);
    },
    keyDown: function(keyCode) {
      return new FakeKeyEvent(keyCode);
    },
    randomString: function() {
      Math.random().toString(36).substring(2);
    },
    prepareStageElement: function() {
      before(function() {
        this.stageElement = document.createElement("div");
        this.stageElement.style.display = "none";
        document.body.appendChild(this.stageElement);
      });
      afterEach(function() {
        this.stageElement.innerHTML = "";
      });
    }
  };

  window.TestHelper = TestHelper;
  window.assert = chai.assert;
})();