<?php
	define("PROJECT_TEMPLATES", $_SERVER['DOCUMENT_ROOT'] . "/RCE/inc/");

	function render($result) {
		$template =	file_get_contents(PROJECT_TEMPLATES . "template.html");
		$template = str_replace('{result}', $result, $template);
		echo $template;
	}

	function secureCmd($ip) {
		exec('ping -c4 ' . $ip, $result);
		return join("<br/>", $result); 
	}

	function entry() {
		$result = "";
		if (isset($_GET['ip'])) {
			$result = secureCmd($_GET['ip']);
		}
		render($result);
	}	

	entry();
?>
