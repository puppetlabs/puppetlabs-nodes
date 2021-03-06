define nodes::vmfusion($inventory_path, $image, $enable = "running") {
   Exec{ path => "/usr/bin:/usr/sbin:/Library/Application Support/VMware Fusion/" }
   File{ owner => root, mode => 644 }

   $vmxfile = "${inventory_path}/${name}/${name}.vmx"

   file {
     # - copy of image (tarfile)
     "$inventory_path/$name":
          source => $image,
          recurse => true,
          replace => false;

     # - vmx from template
     "$vmxfile":
       content => template("nodes/vmx.erb")
   }

   case $enable {
    "running": {
      # - vmrun start from vmx
     exec {"running-${name}":
           command => "vmrun start $vmxfile nogui",
           unless =>  "vmrun list| grep $name",
           require => File["$vmxfile"]
      }
    }
    "stopped":{
     exec {"stopped-${name}":
           command => "vmrun stop $vmxfile",
           onlyif =>  "vmrun list| grep $name",
           require => File["$vmxfile"]
      }
    }
    "default": {
       fail("Enable not set to either running or stopped, set to:$enable")
    }
}
}
