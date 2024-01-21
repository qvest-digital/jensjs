// for index.htm

usefulJS.deferDOM(function onDOMusable() {
	var lst = document.getElementById('sessionlist');
	var msg = document.getElementById('msg');
	var tbl = document.getElementById('sessionlisttbl');
	var ids = {};
	function clkBtn() {
		document.location.href = '/graph.htm#id=' + this.data;
	}
	function pencilBtn() {
		var num = this.data;
		var elts = ids[num];
		elts[1].value = elts[5];
		elts[0].className = "hidden";
		elts[1].className = "";
		elts[2].className = "eb hidden";
		elts[3].className = "eb blk";
		elts[4].className = "eb blk";
	}
	function editOkBtn() {
		var num = this.data;
		var elts = ids[num];
		elts[5] = usefulJS.xhtsafe(elts[1].value);
		elts[1].value = elts[5];
		elts[0].innerHTML = usefulJS.text2html(elts[5]);
		// eslint-disable-next-line no-unused-vars
		usefulJS.ezXHR(function postEvent(status, response, xhr) {
			if (status === 204) {
				elts[0].className = "";
				elts[1].className = "hidden";
				elts[2].className = "eb blk green";
				elts[3].className = "eb hidden";
				elts[4].className = "eb hidden";
			} else {
				elts[3].className = "eb blk red";
			}
		    }, "/api/comment?id=" + num, elts[5]);
	}
	function editNoBtn() {
		var num = this.data;
		var elts = ids[num];
		elts[1].value = elts[5];
		elts[0].className = "";
		elts[1].className = "hidden";
		elts[2].className = "eb blk";
		elts[3].className = "eb hidden";
		elts[4].className = "eb hidden";
	}
	function processResult(j) {
		if (!j.length) {
			msg.innerText = "No sessions available.";
			return;
		}
		msg.innerText = "Processing…";
		var i, r, c, elts = [], e;
		for (i = 0; i < j.length; ++i) {
			if (!Number.isInteger(j[i][0])) {
				console.error("no integer: " + j[i][0]);
				return;
			}
			elts[5] = usefulJS.xhtsafe(j[i][2]);

			r = tbl.insertRow();
			c = r.insertCell();
			e = document.createElement('button');
			e.type = 'button';
			e.className = "blk";
			e.data = j[i][0];
			e.innerText = j[i][0];
			e.onclick = clkBtn;
			c.appendChild(e);
			c = r.insertCell();
			e = document.createElement('tt');
			e.innerText = usefulJS.ISO8601(j[i][1]);
			c.appendChild(e);
			c = r.insertCell();
			e = document.createElement('span');
			e.innerHTML = usefulJS.text2html(elts[5]);
			elts[0] = e; // inner text span
			c.appendChild(e);
			e = document.createElement('textarea');
			e.className = "hidden";
			e.value = elts[5];
			elts[1] = e; // value textarea
			c.appendChild(e);
			c = r.insertCell();
			e = document.createElement('button');
			e.type = 'button';
			e.className = "eb blk";
			e.data = j[i][0];
			e.innerText = '🖉';
			e.onclick = pencilBtn;
			elts[2] = e; // edit button
			c.appendChild(e);
			e = document.createElement('button');
			e.type = 'button';
			e.className = "eb hidden";
			e.data = j[i][0];
			e.innerText = '✔';
			e.onclick = editOkBtn;
			elts[3] = e; // ok button
			c.appendChild(e);
			e = document.createElement('button');
			e.type = 'button';
			e.className = "eb hidden";
			e.data = j[i][0];
			e.innerText = '✘';
			e.onclick = editNoBtn;
			elts[4] = e; // abort button
			c.appendChild(e);

			ids[j[i][0]] = elts;
			elts = [];
		}
		tbl.className = "";
		lst.removeChild(msg);
	}
	msg.innerText = "Loading…";
	usefulJS.ezXHR(function xhrEvent(status, response, xhr) {
		if (status === 200)
			processResult(JSON.parse(response));
		else
			msg.innerText = "Error " + status +
			    " " + xhr.statusText;
	    }, "/api/sessions");
});
