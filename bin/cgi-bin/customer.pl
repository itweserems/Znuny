#!/usr/bin/perl -w
# --
# customer.pl - the global CGI handle file (incl. auth) for OTRS
# Copyright (C) 2001-2002 Martin Edenhofer <martin+code@otrs.org>
# --
# $Id: customer.pl,v 1.8 2002-11-24 23:51:35 martin Exp $
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# --

# use ../../ as lib location
use FindBin qw($Bin);
use lib "$Bin/../..";
use lib "$Bin/../../Kernel/cpan-lib";

use strict;

use vars qw($VERSION @INC);
$VERSION = '$Revision: 1.8 $';
$VERSION =~ s/^.*:\s(\d+\.\d+)\s.*$/$1/;

# --
# 0=off;1=on;
# --
my $Debug = 0; 

# --
# check @INC for mod_perl (add lib path for "require module"!)
# --
push (@INC, "$Bin/../..", "$Bin/../../Kernel/cpan-lib");

# --
# all framework needed  modules 
# (if you use mod_perl with startup.pl, drop this "use Kernel::.." and add
# this to your startup.pl) 
# --
use Kernel::Config;
use Kernel::Config::ModulesCustomerPanel;
use Kernel::System::Log;
use Kernel::System::WebRequest;
use Kernel::System::DB;
use Kernel::System::AuthSession;
use Kernel::System::CustomerAuth;
use Kernel::System::CustomerUser;
use Kernel::System::Permission;
use Kernel::Output::HTML::Generic;

# --
# create common framework objects 1/2
# --
my %CommonObject = ();
$CommonObject{ConfigObject} = Kernel::Config->new();
$CommonObject{LogObject} = Kernel::System::Log->new(
    LogPrefix => $CommonObject{ConfigObject}->Get('CGILogPrefix'),
    %CommonObject,
);
$CommonObject{DBObject} = Kernel::System::DB->new(%CommonObject);
# --
# check common db objects
# --
if (!$CommonObject{DBObject}) {
    print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Error!');
    print $CommonObject{LayoutObject}->CustomerError(
        Message => $DBI::errstr,
        Comment => 'Please contact your admin'
    );
    print $CommonObject{LayoutObject}->CustomerFooter();
    exit (1);
}
$CommonObject{ParamObject} = Kernel::System::WebRequest->new();
# --
# debug info
# --
if ($Debug) {
    $CommonObject{LogObject}->Log(
        Priority => 'debug', 
        Message => 'Global handle started...',
    );
}
# --
# get common framework params
# --
my %Param = ();
# get session id
$Param{SessionName} = $CommonObject{ConfigObject}->Get('CustomerPanelSessionName') || 'CSID';
$Param{SessionID} = $CommonObject{ParamObject}->GetParam(Param => $Param{SessionName}) || '';
# drop old session id (if exists)
my $QueryString = $ENV{"QUERY_STRING"};
$QueryString =~ s/(\?|&|)$Param{SessionName}(=&|=.+?&|=.+?$)/&/;
# definde frame work params
my $FramworkPrams = {
    Lang => '',
    Action => '',
    Subaction => '',
    RequestedURL => $QueryString,
};
foreach my $Key (keys %{$FramworkPrams}) {
    $Param{$Key} = $CommonObject{ParamObject}->GetParam(Param => $Key) 
      || $FramworkPrams->{$Key};
}
# --
# Check if the brwoser sends the SessionID cookie and set the SessionID-cookie 
# as SessionID! GET or POST SessionID have the lowest priority.
# --
if ($CommonObject{ConfigObject}->Get('SessionUseCookie')) {
  $Param{SessionIDCookie} = $CommonObject{ParamObject}->GetCookie(Key => $Param{SessionName});
  if ($Param{SessionIDCookie}) {
    $Param{SessionID} = $Param{SessionIDCookie};
  }
}
# --
# create common framework objects 2/2
# --
$CommonObject{LayoutObject} = Kernel::Output::HTML::Generic->new(
    %CommonObject, 
    Lang => $Param{Lang},
);
$CommonObject{UserObject} = Kernel::System::CustomerUser->new(%CommonObject);
$CommonObject{SessionObject} = Kernel::System::AuthSession->new(%CommonObject);
# --
# application and add on application common objects
# --
foreach ('$Kernel::Config::ModulesCustomerPanel::CommonObject') {
  my $ModuleCommonObject = eval $_;
  foreach my $Key (keys %{$ModuleCommonObject}) {
    # create
    $CommonObject{$Key} = $ModuleCommonObject->{$Key}->new(%CommonObject);
  }
}
# --
# get common application and add on application params
# --
foreach ('$Kernel::Config::ModulesCustomerPanel::Param') {
  my $Param = eval $_;
  foreach my $Key (keys %{$Param}) {
    $Param{$Key} = $CommonObject{ParamObject}->GetParam(Param => $Key) 
      || $Param->{$Key};
  }
}

# --
# check request type
# --
if ($Param{Action} eq "Login") {
    # --
    # get params
    # --
    my $User = $CommonObject{ParamObject}->GetParam(Param => 'User') || '';
    my $Pw = $CommonObject{ParamObject}->GetParam(Param => 'Password') || '';
    # --
    # create AuthObject
    # --
    my $AuthObject = Kernel::System::CustomerAuth->new(%CommonObject);

    # --
    # check submited data
    # --
    if ( $AuthObject->Auth(User => $User, Pw => $Pw) ) {
        # --
        # get user data
        # --
        my %UserData = $CommonObject{UserObject}->CustomerUserDataGet(User => $User);
        # --
        # check needed data
        # --
        if (!$UserData{UserID} || !$UserData{UserLogin}) {
            if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
              # --
              # redirect to alternate login
              # --
              print $CommonObject{LayoutObject}->Redirect(
                ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')."?Reason=SystemError",
              );
            }
            else {
              # --
              # show login screen
              # ---
              print $CommonObject{LayoutObject}->CustomerLogin(
                Title => 'Panic!',
                Message => 'Panic! No UserData!!!',
                %Param,
              );
              exit (0);
            }
        }
        # --
        # pref update 
        # --
        $CommonObject{UserObject}->SetPreferences(
            UserID => $UserData{UserID},
            Key => 'UserLastLogin',
            Value => time(),
        );
        # --
        # create new session id
        # --
        my $NewSessionID = $CommonObject{SessionObject}->CreateSessionID(
            %UserData,
            UserType => 'Customer',
        );
        # --
        # create a new LayoutObject with SessionIDCookie
        # --
        my $LayoutObject = Kernel::Output::HTML::Generic->new(
          SetCookies => {
	      SessionIDCookie => $CommonObject{ParamObject}->SetCookie(
		  Key => $Param{SessionName},
		  Value => $NewSessionID,
		  Expires => '+24h',
              ),
          },
          SessionID => $NewSessionID, 
          SessionName => $Param{SessionName},
          %CommonObject,
        );

        # --
        # redirect with new session id and old params
        # --
        # prepare old redirect URL -- do not redirect to Login or Logout (loop)!
        if ($Param{RequestedURL} =~ /Action=(Logout|Login)/) {
            $Param{RequestedURL} = '';
        }
        # --
        # redirect with new session id
        # --
        print $LayoutObject->Redirect(OP => "$Param{RequestedURL}");
    }
    # --
    # login is vailid
    # --
    else {
        if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
            # --
            # redirect to alternate login
            # --
            $Param{RequestedURL} = $CommonObject{LayoutObject}->LinkEncode($Param{RequestedURL});
            print $CommonObject{LayoutObject}->Redirect(
		 ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL').
		   "?Reason=LoginFailed&RequestedURL=$Param{RequestedURL}",
            );
        }
        else {
            # --
            # show normal login
            # --
            print $CommonObject{LayoutObject}->CustomerLogin(
		Title => 'Login',          
		Message => 'Login failed! Your username or password was entered incorrectly.',
		User => $User,
		%Param,
            );
        }
    }
}
# --
# Logout
# --
elsif ($Param{Action} eq "Logout"){
    if ( $CommonObject{SessionObject}->CheckSessionID(SessionID => $Param{SessionID}) ) {
        # --
        # get session data
        # --
        my %UserData = $CommonObject{SessionObject}->GetSessionIDData(
          SessionID => $Param{SessionID},
        );
        # --
        # create new LayoutObject with new '%Param' and '%UserData'
        # --
        $CommonObject{LayoutObject} = Kernel::Output::HTML::Generic->new(
          SetCookies => {
              SessionIDCookie => $CommonObject{ParamObject}->SetCookie(
		  Key => $Param{SessionName},
		  Value => '',
		  Expires => '-24d',
	      ),
          },
          %CommonObject,
          %Param,
          %UserData,
        );
        # --
        # remove session id
        # --
        if ( $CommonObject{SessionObject}->RemoveSessionID(SessionID => $Param{SessionID}) ) {
            if ($CommonObject{ConfigObject}->Get('CustomerPanelLogoutURL')) {
              # --
              # redirect to alternate login 
              # --
              print $CommonObject{LayoutObject}->Redirect(
                ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLogoutURL')."?Reason=Logout",
             );
           }
           else {
             # --
             # show logout screen
             # --
             print $CommonObject{LayoutObject}->CustomerLogin(
               Title => 'Logout',
               Message => 'Logout successful. Thank you for using OTRS!',
               %Param,
             );
           }
        }  
        else {
            print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Logout');
            print $CommonObject{LayoutObject}->CustomerError(
              Message => 'Can`t remove SessionID',
              Comment => 'Please contact your admin!'
            );
            $CommonObject{LogObject}->Log(
		Message => 'Can`t remove SessionID',
		Priority => 'error',
            );
            print $CommonObject{LayoutObject}->CustomerFooter();
        }
    }
    else {
        if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
            # --
            # redirect to alternate login
            # --
            $Param{RequestedURL} = $CommonObject{LayoutObject}->LinkEncode($Param{RequestedURL});
            print $CommonObject{LayoutObject}->Redirect(
		 ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL').
		  "?Reason=InvalidSessionID&RequestedURL=$Param{RequestedURL}",
            );
        }
        else {
            # --
            # show login screen
            # --
            print $CommonObject{LayoutObject}->CustomerLogin(
		Title => 'Logout',
		Message => 'Invalid SessionID!',
		%Param,
            );
        }
    }
}
# --
# CustomerLostPassword
# --
elsif ($Param{Action} eq "CustomerLostPassword"){
    # -- 
    # check feature
    # --
    if (! $CommonObject{ConfigObject}->Get('CustomerPanelLostPassword')) {
        # --
        # show normal login
        # --
        print $CommonObject{LayoutObject}->CustomerLogin(
           Title => 'Login',
           Message => 'Feature not acitv!',
        );
        exit 0;
    }
    # --
    # get params
    # --
    my $User = $CommonObject{ParamObject}->GetParam(Param => 'User') || '';
    # --
    # get user data
    # --
    my %UserData = $CommonObject{UserObject}->CustomerUserDataGet(User => $User);
    if (! $UserData{UserID}) {
        print $CommonObject{LayoutObject}->CustomerLogin(
           Title => 'Login',
           Message => 'There is no account with that login name.',
        );
    }
    else {
        # get new password
        $UserData{NewPW} = $CommonObject{UserObject}->GenerateRandomPassword();
        # update new password
        $CommonObject{UserObject}->SetPassword(UserLogin => $User, PW => $UserData{NewPW});
        # send notify email
        my $EmailObject = Kernel::System::EmailSend->new(%CommonObject);
        my $Body = $CommonObject{ConfigObject}->Get('CustomerPanelBodyLostPassword') 
          || "New Password is: <OTRS_NEWPW>";
        my $Subject = $CommonObject{ConfigObject}->Get('CustomerPanelSubjectLostPassword')
          || 'New Password!';
        foreach (keys %UserData) {
            $Body =~ s/<OTRS_$_>/$UserData{$_}/gi;
        }
        if ($EmailObject->SendNormal(
          To => $UserData{UserEmail}, 
          Subject => $Subject,
          Body => $Body)) {
            print $CommonObject{LayoutObject}->CustomerLogin(
              Title => 'Login',
              Message => "Sent new password to: ".$UserData{"UserEmail"},
              User => $User,
            );
        }
        else {
            print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Error');
            print $CommonObject{LayoutObject}->CustomerError();
            print $CommonObject{LayoutObject}->CustomerFooter();
        }
    }
}
# --
# create new customer account
# --
elsif ($Param{Action} eq "CustomerCreateAccount"){
    # -- 
    # check feature
    # --
    if (! $CommonObject{ConfigObject}->Get('CustomerPanelCreateAccount')) {
        # --
        # show normal login
        # --
        print $CommonObject{LayoutObject}->CustomerLogin(
           Title => 'Login', 
           Message => 'Feature not acitv!',
        );
        exit 0;
    }
    # --
    # get params
    # --
    my %GetParams = ();
    foreach (qw(Login Pw Email Salutation Firstname Lastname)) {
        $GetParams{$_} = $CommonObject{ParamObject}->GetParam(Param => $_) || '';
    }
    # --
    # check needed params
    # --
    if (!$GetParams{CustomerID}) {
        $GetParams{CustomerID} = $GetParams{Email};
    }
    if (!$GetParams{Login}) {
        $GetParams{Login} = $GetParams{Email};
    }
    # --
    # get user data
    # --
    my %UserData = $CommonObject{UserObject}->CustomerUserDataGet(User => $GetParams{Login});
    if ($UserData{UserID}) {
        print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Error');
        print $CommonObject{LayoutObject}->CustomerWarning(
            Message => 'This account exists.',
            Comment => 'Please press Back and try again.'
        );
        print $CommonObject{LayoutObject}->CustomerFooter();
    }
    else {
        if ($CommonObject{UserObject}->CustomerUserAdd(
            %GetParams,
            Comment => "Added via Customer Panel (".localtime().")",
            ValidID => 1,
            UserID => $CommonObject{ConfigObject}->Get('CustomerPanelUserID'),
        )) {
            print $CommonObject{LayoutObject}->CustomerLogin(
                Title => 'Login',
                Message => "New account created. Login as '$GetParams{Login}'",
                User => $GetParams{Login},
            );
        }
        else {
            print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Error');
            print $CommonObject{LayoutObject}->CustomerWarning(
                Comment => 'Please press Back and try again.'
            );
            print $CommonObject{LayoutObject}->CustomerFooter();
        }
    }
}
# --
# show login site
# --
elsif (!$Param{SessionID}) {
    if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
        # --
        # redirect to alternate login
        # --
        $Param{RequestedURL} = $CommonObject{LayoutObject}->LinkEncode($Param{RequestedURL});
        print $CommonObject{LayoutObject}->Redirect(
            ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL').
             "?RequestedURL=$Param{RequestedURL}",
        );
    }
    else {
        # --
        # login screen
        # --
        print $CommonObject{LayoutObject}->CustomerLogin(
            Title => 'Login',
            %Param,
        );
    }
}
# --
# run modules if exists a version value
# --
elsif (eval '$Kernel::Modules::'. $Param{Action} .'::VERSION' 
  && eval '$Param{Action} =~ /$Kernel::Config::ModulesCustomerPanel::Allow/'){
    # --
    # check session id
    # --
    if ( !$CommonObject{SessionObject}->CheckSessionID(SessionID => $Param{SessionID}) ) {
        if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
            # --
            # redirect to alternate login
            # --
            $Param{RequestedURL} = $CommonObject{LayoutObject}->LinkEncode($Param{RequestedURL});
            print $CommonObject{LayoutObject}->Redirect(
              ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL').
               "?Reason=InvalidSessionID&RequestedURL=$Param{RequestedURL}",
            );
        }
        else {
            # --
            # show login
            # --
            print $CommonObject{LayoutObject}->CustomerLogin(
                Title => 'Login',
                Message => $Kernel::System::AuthSession::CheckSessionID,
                %Param,
            );
        }
    }
    # --
    # run module
    # --
    else { 
        # --
        # get session data
        # --
        my %UserData = $CommonObject{SessionObject}->GetSessionIDData(
            SessionID => $Param{SessionID},
        );
        # --
        # check needed data
        # --
        if (!$UserData{UserID} || !$UserData{UserLogin} || $UserData{UserType} ne 'Customer') {
            if ($CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')) {
		# --
		# redirect to alternate login
		# --
		print $CommonObject{LayoutObject}->Redirect(
			ExtURL => $CommonObject{ConfigObject}->Get('CustomerPanelLoginURL')."?Reason=SystemError",
		);
            }
            else {
		# --
		# show login screen
		# ---
		print $CommonObject{LayoutObject}->CustomerLogin(
			Title => 'Panic!',
			Message => 'Panic! Invalid Session!!!',
			%Param,
		);
		exit (0);
            }
        }
        # --
        # create new LayoutObject with new '%Param' and '%UserData'
        # --
        $CommonObject{LayoutObject} = Kernel::Output::HTML::Generic->new(
            %CommonObject, 
            %Param, 
            %UserData,
        );

        # debug info
        if ($Debug) {
            $CommonObject{LogObject}->Log(
                Priority => 'debug',
                Message => 'Kernel::Modules::' . $Param{Action} .'->new',
            );
        }
        # --
        # prove of concept! - create $GenericObject
        # --
        my $GenericObject = ('Kernel::Modules::'.$Param{Action})->new(
            %CommonObject,
            %Param,
            %UserData,
        );

        # debug info
        if ($Debug) {
            $CommonObject{LogObject}->Log(
                Priority => 'debug',
                Message => ''. 'Kernel::Modules::' . $Param{Action} .'->run',
            );
        }
        # --
        # ->Run $Action with $GenericObject
        # --
        print $GenericObject->Run();

    }
}
# --
# else print an error screen
# --
else { 
    # create new LayoutObject with '%Param'
    my %Data = $CommonObject{SessionObject}->GetSessionIDData(
        SessionID => $Param{SessionID},
    );
    $CommonObject{LayoutObject} = Kernel::Output::HTML::Generic->new(
        %CommonObject, 
        %Param, 
        %Data,
    );
    print $CommonObject{LayoutObject}->CustomerHeader(Title => 'Error');
    print $CommonObject{LayoutObject}->CustomerError(
        Message => "Action '$Param{Action}' not found!",
        Comment => "Perhaps the admin forgot to load \"Kernel::Modules::$Param{Action}\"!",
    );
    print $CommonObject{LayoutObject}->CustomerFooter();
}

# --
# debug info
# --
if ($Debug) {
    $CommonObject{LogObject}->Log(
        Priority => 'debug',
        Message => 'Global handle stopped.',
    );
}
# --
# db disconnect && undef %CommonObject %% undef %
# --
$CommonObject{DBObject}->Disconnect();
undef %Param;
undef %CommonObject;

