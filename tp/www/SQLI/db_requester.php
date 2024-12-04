<?php

	function request($sql) {
		$conn =new PDO('mysql:host=db;dbname=sqli_db', 'sqli_user', '609cd9eecebfb63ba1c2'); 
		$result = $conn->query($sql);
		return $result->fetchAll(PDO::FETCH_ASSOC);
	}

?>
