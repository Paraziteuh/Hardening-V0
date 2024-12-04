<?php
	define("PROJECT_ROOT", $_SERVER['DOCUMENT_ROOT'] . "/SQLI/");
	define("PROJECT_TEMPLATES", PROJECT_ROOT . "inc/");
	require_once(PROJECT_ROOT . "db_requester.php");

	function render($users, $result) {
		$template =	file_get_contents(PROJECT_TEMPLATES . "template.html");
		$users = join('<br/>', $users);
		$result = join('<br/>', $result);
		$template = str_replace('{users}', $users, $template);
		$template = str_replace('{result}', $result, $template);
		echo $template;
	}

	function sanitize($param) {
		//implement me
		return $param;	
	}


	function getUserInfos($id, $nickname) {
		$nickname = sanitize($nickname);
		$id = sanitize($id);
		$query = "SELECT id,nickname,location,comments FROM users WHERE id=$id AND nickname='$nickname';";
		echo $query;
		$result = request($query); 
		if ($result) {
			return $result[0];	
		}
		return ["[-] User not found"];
	}

	function listUsers() {
		$query = "SELECT id,nickname FROM users;";
		$result = request($query);
		$users = [];
		foreach($result as $row) {
			$nickname = $row['nickname'];
			$id = $row['id'];
			$link = sprintf("<a href='/SQLI/index.php?nickname=%s&id=%d'>%s</a>", $nickname, $id, $nickname);
			array_push($users, $link);	
		}
		return $users;
	}

	function entry() {
		$users = listUsers();
		$result = [];
		if (isset($_GET['nickname']) && isset($_GET['id'])) {
			$result = getUserInfos($_GET['id'], $_GET['nickname']);
		}
		render($users, $result);
	}	

	entry();
?>
