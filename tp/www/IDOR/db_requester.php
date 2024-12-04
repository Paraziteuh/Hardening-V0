<?php

	function request($sql, $params) {
		$conn =new PDO('mysql:host=db;dbname=idor_db', 'idor_user', '0a04ffebd4186d8cc7f1'); 
		$stmt = $conn->prepare($sql);
		$stmt->execute($params);
		return $stmt->fetchAll(PDO::FETCH_ASSOC);
	}

?>
