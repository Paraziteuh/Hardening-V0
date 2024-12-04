<?php
	define("PROJECT_TEMPLATES", $_SERVER['DOCUMENT_ROOT'] . "/XSS/inc/");

	function render($result) {
		$template =	file_get_contents(PROJECT_TEMPLATES . "template.html");
		$template = str_replace('{result}', $result, $template);
		echo $template;
	}

	function entry() {
		$result = isset($_GET['val']) ? $_GET['val'] : "empty";
		render($result);
	}	

	entry();
?>
