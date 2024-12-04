<?php
	define("PROJECT_TEMPLATES", $_SERVER['DOCUMENT_ROOT'] . "/UPLOAD/inc/");
	define("UPLOAD_DIR", $_SERVER['DOCUMENT_ROOT'] . "/UPLOAD/FILES/");

	function render($result) {
		$template =	file_get_contents(PROJECT_TEMPLATES . "template.html");
		$template = str_replace('{result}', $result, $template);
		echo $template;
	}


	function upload() {
		$file = UPLOAD_DIR . basename($_FILES['file']['name']);
		move_uploaded_file($_FILES['file']['tmp_name'], $file);
		echo $file;
	}

	function entry() {
		$result = "";
		if (isset($_FILES['file'])) {
			upload();
		}	
		render($result);
	}	

	entry();
?>
