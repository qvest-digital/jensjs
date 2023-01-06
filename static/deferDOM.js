/*-
 * Copyright © 2020
 *	mirabilos <m@mirbsd.org>
 *
 * Provided that these terms and disclaimer and all copyright notices
 * are retained or reproduced in an accompanying document, permission
 * is granted to deal in this work without restriction, including un‐
 * limited rights to use, publicly perform, distribute, sell, modify,
 * merge, give away, or sublicence.
 *
 * This work is provided “AS IS” and WITHOUT WARRANTY of any kind, to
 * the utmost extent permitted by applicable law, neither express nor
 * implied; without malicious intent or gross negligence. In no event
 * may a licensor, author or contributor be held liable for indirect,
 * direct, other damage, loss, or other issues arising in any way out
 * of dealing in the work, even if advised of the possibility of such
 * damage or existence of a defect, except proven that it results out
 * of said person’s immediate fault when using the work as intended.
 */

/* deferDOM library {{{ */
var deferDOM = (function () {
	var called = 0;
	var tmo = false;
	var callbackfns = [];
	var handler = function handler() {
		/* execute once only */
		if (called++)
			return;
		/* clear event handlers and timers */
		if (document.addEventListener) {
			document.removeEventListener("DOMContentLoaded",
			    handler, false);
			window.removeEventListener("load", handler, false);
		} else {
			if (tmo !== false)
				window.clearTimeout(tmo);
			window.detachEvent("onload", handler);
		}
		/* run user callbacks */
		for (var i = 0; i < callbackfns.length; ++i)
			callbackfns[i]();
	};

	/* install DOM readiness listeners */

	if (document.addEventListener) {
		/* Opera 9 and other modern browsers */
		document.addEventListener("DOMContentLoaded", handler, false);
		/* last resort: always works, but later than possible */
		window.addEventListener("load", handler, false);
	} else {
		/* IE or something */
		var tryPoll = false;
		if (document.documentElement.doScroll) {
			try {
				tryPoll = !window.frameElement;
			} catch (e) {}
		}
		if (tryPoll) {
			tryPoll = document.documentElement.doScroll;
			var poll = function poll() {
				try {
					tryPoll("left");
				} catch (e) {
					tmo = window.setTimeout(poll, 50);
					return;
				}
				handler();
			};
			poll();
		}
		/* generic ancient browser */
		var rdychange = function rdychange() {
			if (document.readyState === "complete")
				handler();
			/* detach if ever called from anywhere */
			if (!called)
				return;
			document.detachEvent("onreadystatechange", rdychange);
		};
		document.attachEvent("onreadystatechange", rdychange);
		/* last resort: always works, but later than possible */
		window.attachEvent("onload", handler);
	}

	/* already loaded? */
	if (document.readyState === "complete")
		handler();

	/* function that is called by the user */
	return function deferDOM(cb) {
		/* DOM not ready yet? */
		if (!called) {
			/* enqueue into list of callbacks to run */
			if (typeof(cb) === "function")
				callbackfns.push(cb);
			return (false);
		}
		/* already ready, so just run callback now */
		if (typeof(cb) === "function")
			cb();
		return true;
	};

	/**
	 * Usage:
	 *
	 * • deferDOM(some_function);
	 *   enqueues the function as callback (or runs it now)
	 * • deferDOM()
	 *   just returns the status
	 *
	 * Both return true if the DOM is ready, false otherwise.
	 */
    })();
/* deferDOM library }}} */
