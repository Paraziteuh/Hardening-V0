<?php
	session_start();
	define("PROJECT_ROOT", $_SERVER['DOCUMENT_ROOT'] . "/IDOR/");
	define("PROJECT_TEMPLATES", PROJECT_ROOT . "inc/");
	require_once(PROJECT_ROOT . "db_requester.php");

	function render($page) {
		$template =	file_get_contents(PROJECT_TEMPLATES . $page);
		echo $template;
	}

	function checkCredentials($login, $password) {
		$sql = "SELECT id, login, password FROM users WHERE login=:login AND password=:password";
		$password = hash('sha256', $password);
		$params = array(":login" => $login, ":password" => $password);
		return request($sql, $params);
	}


	function createSession($result) {
		$_SESSION['id'] = $result[0]['id']; 
	}


	function redirect() {
		header('Location: /IDOR/mailbox.php');
		exit();	
	}

	function entry() {
		if (isset($_POST['login']) && isset($_POST['password'])) {
			$login = $_POST['login'];
			$password = $_POST['password'];
			$result = checkCredentials($login, $password);
			if ($result) {
				createSession($result);
				redirect();
			}
		}
		render("login.html");
	}	

	//entry point
	if (isset($_SESSION['id'])) {
		redirect();   
	} else {
		entry();
	}
?>
