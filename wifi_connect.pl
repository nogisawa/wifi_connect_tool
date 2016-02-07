#!/usr/bin/perl

use warnings;

#設定
my $interface = "wlan0"; #無線LANインターフェイス
my $command_iw = "iw"; # iwコマンド
my $command_ip = "ip"; # ipコマンド


my $count;
my $cnt = 0;
my @ap_list;

# Wifiリストを作成し、一覧表示する部分。
# iwコマンドでスキャンした結果を整形して配列に挿入し、表示。	
my @iw_scan_result = `$command_iw dev $interface scan  | sed -e 's\/\\t\/\/g' | sed -e 's\/\\s\/\/g'`;
#my @iw_scan_result = `cat test.txt`;
chomp(@iw_scan_result);

# iwコマンドの結果が異様に短い場合AP未発見として終了する。
if( @iw_scan_result < 3  ){

	print "AP Not Found.\n";
	die();

}

my $ap_id = -1;
for( $cnt=0; $cnt<@iw_scan_result; $cnt++  ){

	#BSS
	if( $iw_scan_result[$cnt] =~ /^BSS[0-9a-fA-F]{2}:.*$/  ){

		$ap_id++;

		#initialize
		$ap_list[$ap_id]->{essid}   = "";
                $ap_list[$ap_id]->{signal}  = "";
                $ap_list[$ap_id]->{encrypt} = "open";

		$iw_scan_result[$cnt] =~ /^BSS([0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}).*$/;
		$ap_list[$ap_id]->{bssid} = $1;

	}

	#ESS ID
	if( $iw_scan_result[$cnt] =~ /^SSID:.*$/  ){

		$iw_scan_result[$cnt] =~ /^SSID:(.*$)/;
		$ap_list[$ap_id]->{essid} = $1;

	}

	#signal
	if( $iw_scan_result[$cnt] =~ /^signal:/ ){

                $iw_scan_result[$cnt] =~ /^signal:((-|)\d{1,3}.\d{1,3})dBm$/;
                $ap_list[$ap_id]->{signal} = $1;

        }

	#WPA
	if( $iw_scan_result[$cnt] =~ /^\*Authenticationsuites:PSK/ ){

		$ap_list[$ap_id]->{encrypt} = "wpa";

        }

	#frep
	if( $iw_scan_result[$cnt] =~ /^freq:/ ){

                $iw_scan_result[$cnt] =~ /^freq:(\d+)$/;
                $ap_list[$ap_id]->{freq} = $1;

        }

	

}

# 一覧取得したWifiリストからどのAPを選択するかの入力画面
# 入力した数字が一覧にある数より大きかった場合は繰り返し入力を求める。
# あまりに間違えが多い場合は終了する。
for( $cnt=0; $cnt<$ap_id; $cnt++  ){

	print "$cnt : $ap_list[$cnt]->{essid}\t$ap_list[$cnt]->{bssid}\t$ap_list[$cnt]->{encrypt}\t$ap_list[$cnt]->{signal}dBm\t$ap_list[$cnt]->{freq}MHz\n";
}

my $the_number_of_APs = $ap_id;
my $connect_ap_number;

for ( $count=0; $count<6; $count++ ){

	print "Which AP Connect? ";
	$connect_ap_number = <STDIN>;
	chomp($connect_ap_number);

	# Check number only?
	if( $connect_ap_number =~ /^\d{1,2}$/ && $connect_ap_number <= $the_number_of_APs ){

		last;

	 }		

	print "Invalid Input.\n";

	if( $count >= 5  ){ 

		print "Many wrongs, abord.\n";
		die();

	}

}

# 選択が完了したら、暗号化方式の選択。
# もし$ap_list[]->{encrypt}にwpaが入っている場合はここは省略される。
print "You selected $ap_list[$connect_ap_number]->{essid}\n";

my $connect_ap_name = $ap_list[$connect_ap_number]->{essid};

for ( $count=0; $count<=2; $count++ ){

	if( $ap_list[$connect_ap_number]->{encrypt} eq 'open'  ){

		print "0 ... Non Encrypted\n";
		print "1 ... WEP\n";
		print "2 ... WPA/WPA2\n";

		print "Encryption Type? ";
		$connect_ap_encrypt_type = <STDIN>;

		# Check number only?
		if( $connect_ap_encrypt_type =~ /^\d{1,2}$/ && $connect_ap_encrypt_type <= 2 ){

			last;

		 }		

		print "Invalid Input.\n";

		if( $count >= 5  ){ 

			print "Many wrongs, abord.\n";
			die();

		}

	}elsif( $ap_list[$connect_ap_number]->{encrypt} eq 'wpa'  ){


		$connect_ap_encrypt_type = 2;

	}

}

# 暗号化方式が決まったら接続処理に入る。
# ここでWPAの接続が残っていると多重起動になってしまい、旧接続と新接続の奪い合いになるので
# それを回避するためwpa_supplicantをkillしておく。
my @ps_wpa_list = `ps alx | grep wpa_supplicant | grep -v grep | grep ${interface} | awk \'\{print \$3\}\'`;
chomp @ps_wpa_list;

for ( $count=0; $count<@ps_wpa_list; $count++ ){
    system("kill $ps_wpa_list[$count]");
}

# setting by type
if ( $connect_ap_encrypt_type == 0 ){

    #Non encrypt
    print "comming soon...\n";

}elsif( $connect_ap_encrypt_type == 1   ){

    #WEP
    print "comming soon...\n";

}elsif( $connect_ap_encrypt_type == 2  ){
   
    # WPAの場合の接続処理。
    # ここではwpa_supplicantを利用する
    $connect_ap_passphrase_file = "/etc/wpa_supplicant/${connect_ap_name}.conf";
    
    print "$connect_ap_passphrase_file\n";

    if( ! -r $connect_ap_passphrase_file ){

	for ( $count=0; $count<=5; $count++ ){

        	print "enter passphrase : ";
        	$connect_ap_passphrase_text = <STDIN>;
		chomp($connect_ap_passphrase_text);

        	# Check number only?
        	if( $connect_ap_passphrase_text =~ /^.{8,32}$/ ){

                	last;

         	}

        	print "Invalid Input.\n";

        	if( $count >= 5  ){

                	print "Many wrongs, abord.\n";
                	die();

        	}

	}


	system ("wpa_passphrase ${connect_ap_name} ${connect_ap_passphrase_text} > ${connect_ap_passphrase_file}");

    }

    system("wpa_supplicant -B -i $interface -c /etc/wpa_supplicant/${connect_ap_name}.conf -D wext");
    system("dhclient $interface");

}
