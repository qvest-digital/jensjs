module.exports = {
	"env": {
		"browser": true
	},
	"extends": "eslint:recommended",
	"overrides": [
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
