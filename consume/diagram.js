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
	if (status !== 200 || response === "") {
		g.loading(false);
		alert("loading qdelay failed with HTTP status " +
		    status + " " + xhr.statusText);
		return;
	}
	var data = ('[[' + response).slice(0, -1) + ']]';
	data = JSON.parse(data.replace(g.re_nl, '],['));
	g.gLatency.updateOptions({"file": data});
	g.loading(false);
    };

g.reload_bw = function reload_bw(status, response, xhr) {
	if (status !== 200 || response === "") {
		g.loading(false);
		alert("loading qdelay failed with HTTP status " +
		    status + " " + xhr.statusText);
		return;
	}
	var data = ('[[' + response).slice(0, -1) + ']]';
	data = JSON.parse(data.replace(g.re_nl, '],['));
	g.gBW.updateOptions({"file": data});
	g.loading(false);
    };

usefulJS.deferDOM(function onDOMReady() {
	g.loadingelt = document.getElementById('loadingelt');
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
	g.gBW = new Dygraph(document.getElementById('divBandwidth'),
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
				"digitsAfterDecimal": 6
			},
			"y2": {
				"digitsAfterDecimal": 6
			}
		},
		"connectSeparatedPoints": true,
		"xlabel": "s",
		"xLabelHeight": 0,
		"ylabel": "Mbit/s",
		"labels": ["time", "load", "capacity"],
		"resizable": "passive"
	    });
	usefulJS.hashlib(g.onHashChange);
	g.reload(); // initial load
    });
