define def_test($ip ="", $host_aliases ="") {
 host{$title: 
   ip => $ip,
   host_aliases => $host_aliases
 } 
}
 
make_node("test")
