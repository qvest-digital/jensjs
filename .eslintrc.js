module.exports = {
	"env": {
		"browser": true
	},
	"extends": "eslint:recommended",
	"overrides": [
		{
			"files": [ "**/diagram.js" ],
			"globals": {
				"Dygraph": "readonly",
				"usefulJS": "readonly"
			},
		},
		{
			"files": [ "**/sessionlist.js" ],
			"globals": {
				"usefulJS": "readonly"
			},
		},
		{
			"files": [ "**/useful.js" ],
			"rules": {
				// false positive:
				// 27:22  error  'exports' is not defined
				"no-undef": 0,
				// uses arguments:
				// 140:30  error  'dateobject' is defined but never used
				// 176:32  error  'dateobject' is defined but never used
				"no-unused-vars": 0,
				// uses \x0c deliberately
				"no-control-regex": 0,
				// one empty catch block
				// 333:16  error  Empty block statement
				"no-empty": 0,
			},
		},
		{
			"env": {
				"node": true
			},
			"files": [
				".eslintrc.{js,cjs}"
			],
			"parserOptions": {
				"sourceType": "script"
			}
		}
	],
	"parserOptions": {
		"ecmaVersion": 5
	},
	"rules": {
		"no-mixed-spaces-and-tabs": ["error", "smart-tabs"],
	}
}
