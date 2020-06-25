package spork.core;

typedef EntityDef = {
	var properties: Dynamic;
	var components: Array<ComponentDef>;
}

typedef ComponentDef = {
	var name: String;
	var params: Dynamic;
}
