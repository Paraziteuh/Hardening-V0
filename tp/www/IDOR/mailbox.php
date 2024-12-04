<?php
	session_start();
	define("PROJECT_ROOT", $_SERVER['DOCUMENT_ROOT'] . "/IDOR/");
	define("PROJECT_TEMPLATES", PROJECT_ROOT . "inc/");
	require_once(PROJECT_ROOT . "db_requester.php");

	function render($messages, $mail) {
		$template =	file_get_contents(PROJECT_TEMPLATES . "mailbox.html");
		$mailTemplate = "";
		$arrayTuple = [];

		//generate table for mailbox_content
		foreach ($messages as $msg) {
			$line = "<tr>"; 
			foreach($msg as $data) {
				$line .= "<td>";
				$line .= sprintf("<a href='/IDOR/mailbox.php?idMsg=%s'>%s</a>", $msg['id'], $data);
				$line .= "</td>";
			}
			$line .= "</tr>";	
			array_push($arrayTuple, $line);
		}

		//display mail content
		if ($mail!== "") {
			$mail = $mail[0];
			$mailTemplate = file_get_contents(PROJECT_TEMPLATES . "message.html");
			$mailTemplate = str_replace('{ID}', $mail['id'], $mailTemplate);
			$mailTemplate = str_replace('{TITLE}', $mail['title'], $mailTemplate);
			$mailTemplate = str_replace('{CONTENT}', $mail['content'], $mailTemplate);
		}
		//generate template
		$template = str_replace('{MAILBOX_CONTENT}', join('\n', $arrayTuple), $template);
		$template = str_replace('{MAIL_CONTENT}', $mailTemplate, $template);
		echo $template;
	}

	function getMessages() {
		$sql = "SELECT m.id, m.title FROM messages m JOIN mailbox mb WHERE m.id=mb.id_message AND mb.id_user=:idUser";
		$params = array(":idUser" => $_SESSION['id']);
		$messages = request($sql, $params);
		return $messages;
	}

	function getMessageContent($idMsg) {
		$sql = "SELECT id, content, title FROM messages WHERE id=:idMsg";
		$params = array(":idMsg" => $idMsg);
		$content = request($sql, $params);
		return $content;
	}

	function entry() {
		$messages = getMessages();
		$msgBody = "";
		if (isset($_GET['idMsg'])) {
			$msgBody = getMessageContent($_GET['idMsg']);	
		}
		render($messages, $msgBody);
	}

	//entry point
	if (isset($_SESSION['id'])) {
		entry();
	} else {
		header("Location: /IDOR/index.php");
	}
?>
