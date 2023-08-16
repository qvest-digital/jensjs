// for graph.htm

var g = {};

function btnSess() {
	document.location.href = '/';
}

g.nloading = 0;
g.loading = function loading(on) {
	g.nloading += on === true ? 1 : on === false ? -1 : on;
	g.loadingelt.className = g.nloading > 0 ? "" : "hidden";
    };

g.onHashChange = function onHashChange(newhash, ign) {
	if (!ign)
		g.reload();
    };

g.reload = function reload() {
	g.id = String(usefulJS.hashlib.get('id'));
	if (!/^[1-9][0-9]*$/.test(g.id)) {
		alert("invalid ID: " + g.id);
		return;
	}
	g.sessnum.innerHTML = g.id;
	g.loading(true);
	usefulJS.ezXHR(g.reload1, '/api/session?id=' + g.id);
    };

g.reload1 = function reload1(status, response, xhr) {
	if (status !== 200) {
		g.loading(false);
		alert("loading session failed with HTTP status " +
		    status + " " + xhr.statusText);
		return;
	}
	var data = JSON.parse(response);
	if (String(data.id) !== g.id) {
		g.loading(false);
		alert("loading session failed with invalid data");
		return;
	}
	g.sesprop.innerHTML = "Session #" + g.id + " properties:" +
	    " • <b>Time 0:</b> <tt>" + usefulJS.ISO8601(data.ms) + "</tt>" +
	    " • <b>timestamp:</b> <tt>" + usefulJS.ISO8601(data.ts) + "</tt>" +
	    " • <b>comment:</b> " + (data.c == "" ? "<i>(none)</i>" :
	    usefulJS.text2html(usefulJS.xhtsafe(data.c)));
	g.loading(2); // number of AJAX requests we’ll start
	usefulJS.ezXHR(g.reload_qdelay, '/api/session/qdelay?id=' + g.id);
	usefulJS.ezXHR(g.reload_bw, '/api/session/bandwidth?id=' + g.id);
	g.loading(false); // for myself
    };

g.re_nl = /\n/g;
g.reload_qdelay = function reload_qdelay(status, response, xhr) {
	if (status !== 200) {
		g.loading(false);
		alert("loading qdelay failed with HTTP status " +
		    status + " " + xhr.statusText);
		return;
	}
	if (response === "") {
		g.loading(false);
		console.log("loading qdelay returned no data (yet)");
		return;
	}
	var data = ('[[' + response).slice(0, -1) + ']]';
	data = JSON.parse(data.replace(g.re_nl, '],['));
	g.gLatency.updateOptions({"file": data});
	g.ndyelt.classList.add("loaded-qdelay");
	g.loading(false);
    };

g.reload_bw = function reload_bw(status, response, xhr) {
	if (status !== 200) {
		g.loading(false);
		alert("loading bw failed with HTTP status " +
		    status + " " + xhr.statusText);
		return;
	}
	if (response === "") {
		g.loading(false);
		console.log("loading bw returned no data (yet)");
		return;
	}
	var data = ('[[' + response).slice(0, -1) + ']]';
	data = JSON.parse(data.replace(g.re_nl, '],['));
	g.gBW.updateOptions({"file": data});
	g.ndyelt.classList.add("loaded-bw");
	g.loading(false);
    };

usefulJS.deferDOM(function onDOMReady() {
	g.ndyelt = document.getElementById('ndyelt');
	g.loadingelt = document.getElementById('loadingelt');
	g.sessnum = document.getElementById('sessnum');
	g.sesprop = document.getElementById('sesprop');
	g.gLatency = new Dygraph(document.getElementById('divLatency'),
	    /* initial dummy data */ [[0,0,0],[1,1,1]], {
		"axes": {
			"x": {
				"valueFormatter": function (x) {
					return (String(Number(x).toFixed(6))
					    .replace(/...$/, " $&"));
				    },
				"pixelsPerLabel": 40
			},
			"y": {
				"digitsAfterDecimal": 3
			},
			"y2": {
				"digitsAfterDecimal": 3
			}
		},
		"xlabel": "s",
		"xLabelHeight": 0,
		"ylabel": "milliseconds",
		"labels": ["time", "qdelay", "OWD"],
		"resizable": "passive"
	    });
	var oldFormatter = Dygraph._require('dygraphs/src/plugins/legend.js').defaultFormatter;
	var newFormatter = function newFormatter(data) {
		if (typeof(data.x) !== 'undefined') {
			data.series[2].isVisible = true;
			data.series[2].y = data.dygraph.getValue(data.i, 3);
			if (data.series[2].y !== null)
				data.series[2].yHTML = data.series[2].y + 'b';
		}
		return (oldFormatter(data));
	};
	g.gBW = new Dygraph(document.getElementById('divBandwidth'),
	    /* initial dummy data */ [[0,0,0,null],[1,1,1,null]], {
		"axes": {
			"x": {
				"valueFormatter": function (x) {
					return (String(Number(x).toFixed(6))
					    .replace(/...$/, " $&"));
				    },
				"pixelsPerLabel": 40
			},
			"y": {
				"digitsAfterDecimal": 6
			},
			"y2": {
				"digitsAfterDecimal": 6
			}
		},
		"xlabel": "s",
		"xLabelHeight": 0,
		"ylabel": "Mbit/s",
		"labels": ["time", "load", "capacity", "pktsz"],
		"visibility": [true, true, false],
		"connectSeparatedPoints": true,
		"legendFormatter": newFormatter,
		"underlayCallback": function (ctx, area, dy) {
			var canvasx = function point2canvasx(point) {
				return (area.w * point.x + area.x);
			};
			var points = dy.layout_.points[0];
			var pl = points.length - 1;
			if (pl < 3)
				return;
			if (points[pl].xval == points[0].xval)
				return;
			var elts = [];
			var pps = (canvasx(points[pl]) - canvasx(points[0])) /
			    (points[pl].xval - points[0].xval);
			pps = pps * 8 / 1000000;
			for (var i = 0; i < pl; ++i) {
				var point = points[i];
				var cx = canvasx(point);
				if (cx < 0)
					continue;
				var len = dy.getValue(point.idx, 3);
				if (len === null)
					continue;
				var rate = dy.getValue(point.idx, 2);
				var w = len * pps / rate;
				if (w < 3)
					return;
				elts.push([cx, w]);
			}
			ctx.save();
			var y = 0;
			pl = elts.length;
			for (var i = 0; i < pl; ++i) {
				var e = elts[i];
				ctx.fillStyle = "#000000";
				ctx.fillRect(e[0], y, e[1], 4);
				ctx.fillStyle = "#E2001A";
				ctx.fillRect(e[0] + 1, y + 1, e[1] - 2, 2);
				y ^= 4;
			}
			ctx.restore();
		},
		"resizable": "passive"
	    });
	g.sync = Dygraph.synchronize([
		g.gLatency, g.gBW,
	    ], {
		"range": false
	    });
	usefulJS.hashlib(g.onHashChange);
	g.reload(); // initial load
    });
