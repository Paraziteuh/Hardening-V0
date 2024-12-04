<?php
echo "<html>";echo "<head>"; echo "<title>TP REFACTORISATION"; echo "</title>"; echo "</head>";echo "";
	echo "<body>";
	$a = $_GET['user'];
	$h = $_GET['commande'];
	$c = $_GET['user'];
	$c = $_POST['homeDir'];
	$e = $_SERVER['DOCUMENT_ROOT'];
	$b = $_GET['k'];
	$f = $_POST['e'];
	$g = $_GET['u'];
	$w = "/SPAGHETTI/";
	$k = " ";




$b=$a; $c=$f;
$f=$k;
$c=$b;
$s=$k;
$e .= $w;    	
	if (strcmp($a, "utilisateur") == 0) 
	{
		echo "<p>Bonjour utilisateur</p>";
	}
	else if ($b == "administrateur") {
echo "<p>Bonjour administrateur</p>";
	}
			else if ($c == "martine") {
		echo "<p>Bonjour martine</p>";
			}








if ($a == "utilisateur") 
{
		echo "</br>";
		echo "</br>";
		echo "</br>";
		echo "<p>";
		$s = $e . "/utilisateur";$o=$b; 		$b = $c;      ;$g = $e . $b; $o = " ";		$g = $g . 'fichier.docx' ; $g = 'l'; $g.='s';
system($g . $o . $s);
		echo "<p>";
}
else if ($b == "administrateur") {

		echo "</br>";
		echo "</br>";
		echo "</br>";
		echo "<p>";$s = $e . "/administrateur";		$b = $c;;	$p='ls';$u = 'ls'; $u=$u	;$g = $e . $b;		$g = $g . 'fichier.docx';
system($p . $k . $s);
		echo "<p>";

}
else if ($c == "martine") {

		echo "</br>";
		echo "</br>";
echo "</br>";
$u = "";
		echo "<p>";
				$s = $e . "/martine";$a = 'dossier' . '_rh' . '/'; $z = 'ls' ; $u=$u			;		$b = $c;$g = $e . $b;
$g = $g . 'fichier.docx';
system($z . $k . $s);

		echo "<p>";




}





else {

	echo "don't know you....";

}

	echo "</body>";
echo "</html>";
?>
