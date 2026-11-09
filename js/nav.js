/* Spatial navigation for a TV remote: arrows move to the nearest focusable item
   in that direction on screen. Works the same in RTL because it uses geometry. */
(function () {
  "use strict";
  var current = null, scope = null;

  function focusables() {
    var root = scope || document;
    return Array.prototype.filter.call(root.querySelectorAll(".focusable, .cat, .st"), function (el) {
      if (el.disabled || el.closest("[hidden]")) return false;
      var r = el.getBoundingClientRect();
      return r.width > 0 && r.height > 0;
    });
  }

  function center(r) { return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }

  function focus(el) {
    if (!el) return;
    if (current) current.classList.remove("focused");
    current = el;
    el.classList.add("focused");
    try { el.focus({ preventScroll: true }); } catch (e) { el.focus(); }
    keepVisible(el);
  }

  function keepVisible(el) {
    var box = el.closest(".grid, .cats");
    if (!box) return;
    var r = el.getBoundingClientRect(), b = box.getBoundingClientRect(), pad = 12;
    if (r.top < b.top + pad) box.scrollTop -= (b.top + pad - r.top);
    else if (r.bottom > b.bottom - pad) box.scrollTop += (r.bottom - b.bottom + pad);
  }

  function move(dir) {
    var items = focusables();
    if (!current || items.indexOf(current) < 0) { focus(items[0]); return true; }
    var from = center(current.getBoundingClientRect()), best = null, bestScore = Infinity;
    items.forEach(function (el) {
      if (el === current) return;
      var c = center(el.getBoundingClientRect()), dx = c.x - from.x, dy = c.y - from.y, main, cross;
      if (dir === "left")  { if (dx > -4) return; main = -dx; cross = Math.abs(dy); }
      if (dir === "right") { if (dx < 4)  return; main = dx;  cross = Math.abs(dy); }
      if (dir === "up")    { if (dy > -4) return; main = -dy; cross = Math.abs(dx); }
      if (dir === "down")  { if (dy < 4)  return; main = dy;  cross = Math.abs(dx); }
      var score = main + cross * 2.2;
      if (score < bestScore) { bestScore = score; best = el; }
    });
    if (best) { focus(best); return true; }
    return false;
  }

  window.Nav = {
    move: move,
    focus: focus,
    current: function () { return current; },
    setScope: function (el) { scope = el; },
    first: function (selector) { var el = document.querySelector(selector); if (el) focus(el); return el; },
    forget: function () { if (current) current.classList.remove("focused"); current = null; }
  };
})();
