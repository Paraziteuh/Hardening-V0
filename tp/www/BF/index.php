<?php

	define("PROJECT_TEMPLATES", $_SERVER['DOCUMENT_ROOT'] . "/BF/inc/");

	function render($valid) {
		$template = $valid ? 
			file_get_contents(PROJECT_TEMPLATES . "logged.html") :
			file_get_contents(PROJECT_TEMPLATES . "login.html");		
		echo $template;
	}

	function checkCredentials($login, $password) {
		if (!is_array($login) && !is_array($password)) {
			if (strcmp($login, "admin") == 0 && strcmp($password, "mYs3cuR3pAssWorD!!!") == 0) {
				return true;
			}
		}
		return false;
	}

	function entry() {
		$valid = false;
		if (isset($_POST['login']) && isset($_POST['password'])) {
			$valid = checkCredentials($_POST['login'], $_POST['password']);	
		}
		render($valid);
	}	

	entry();
?>
