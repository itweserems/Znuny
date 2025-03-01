# --
# Copyright (C) 2021 Znuny GmbH, https://znuny.org/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --
## nofilter(TidyAll::Plugin::Znuny::Perl::PerlCritic)
## nofilter(TidyAll::Plugin::Znuny::Perl::SyntaxCheck)

package Kernel::System::ProcessManagement::TransitionValidation::NotEqual;

use parent qw(Kernel::System::ProcessManagement::TransitionValidation::Base);

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionValidation::NotEqual - NotEqual for Transition Validation Module

=head1 DESCRIPTION

All NotEqual functions.

=head1 PUBLIC INTERFACE

=head2 new()

Don't use the constructor directly, use the ObjectManager instead:

    my $NotEqualObject = $Kernel::OM->Get('Kernel::System::ProcessManagement::TransitionValidation::NotEqual');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    $Self->{Name}  = 'NotEqual';
    $Self->{Label} = '( != ) not equal';

    return $Self;
}

=head2 Validate()

Validate Data

    my $Match = $ValidateModuleObject->Validate(
        Data => {
            # TicketData
            TicketID          => 1,
            DynamicField_Make => [
               'Test1',
               'Test2',
               'Test3'
            ]
            # [...]
        },
        FieldName    => 'DynamicField_Make',
        'Transition' => {
            'Name'      => 'Transition 2',
            'Condition' => {
                'Type'             => 'and',
                'ConditionLinking' => 'and',
                'Condition 1'      => {
                    'Fields' => {
                        'DynamicField_Make' => $VAR1->{'Condition'}
                    }
                }
            }
        },
        TransitionName     => 'Transition 2',
        TransitionEntityID => 'T1903007681700000',

        Condition          => {
            Match => 'Test4',
            Type  => 'Equal'
        },
        ConditionName    => 'Condition 1',
        ConditionType    => 'and',
        ConditionLinking => 'and'
    );

Returns:

    $ValidateResult = 1;        # or undef, only returns 1 if Queue is 'Raw'

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    my $LogObject = $Kernel::OM->Get('Kernel::System::Log');

    NEEDED:
    for my $Needed (qw(Data FieldName Condition)) {
        next NEEDED if defined $Param{$Needed};

        $LogObject->Log(
            Priority => 'error',
            Message  => "Parameter '$Needed' is needed!",
        );
        return;
    }

    my $CheckValue = $Self->CheckValueGet(
        %Param,
    );
    return if !defined $CheckValue;

    my $MatchValue = $Self->MatchValueGet(
        %Param,
        MatchValue => $Param{Condition}->{Match},
    );
    return if !defined $MatchValue;

    my $Match = $Self->NotEqual( $CheckValue, $MatchValue );

    return $Match;
}

1;
