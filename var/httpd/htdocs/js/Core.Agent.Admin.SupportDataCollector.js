// --
// Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
// Copyright (C) 2021 Znuny GmbH, https://znuny.org/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (GPL). If you
// did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
// --

"use strict";

var Core = Core || {};
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.SupportDataCollector
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special module function for SupportDataCollector module.
 */
Core.Agent.Admin.SupportDataCollector = (function (TargetNS) {

    /*
    * @name Init
    * @memberof Core.Agent.Admin.SupportDataCollector
    * @function
    * @description
    *      This function initializes module functionality
    */
    TargetNS.Init = function () {

        // Bind event on Generate Support bundle button
        $('#GenerateSupportBundle').on('click', function (Event) {
            Core.UI.Dialog.ShowContentDialog('<div class="Spacing Center LoadingSupportBundleDialog"><span class="AJAXLoader W75pc" title=' + Core.Language.Translate("Generating...") + '></span></div>', Core.Language.Translate("Generating..."), '10px', 'Center', true, undefined, true);

            Core.AJAX.FunctionCall(Core.Config.Get('CGIHandle'), 'Action=' + Core.Config.Get('Action') + ';Subaction=GenerateSupportBundle;', function (Response) {
                var TextClass, ResponseMessage;

                // if the waiting dialog was canceled,
                // do not show the option dialog as well
                if (!$('.Dialog:visible').length) {
                    return;
                }

                Core.UI.Dialog.CloseDialog($('.LoadingSupportBundleDialog'));

                if (!Response.Success) {
                    ResponseMessage = Core.Language.Translate('It was not possible to generate the Support Bundle.'),
                    TextClass = 'Error';

                    Core.UI.Dialog.ShowContentDialog(
                        '<div class="Spacing Center NoSupportBunle"><span class="W50pc ' + TextClass + '" title="' + ResponseMessage + '">' + ResponseMessage + '</span></div>', Core.Language.Translate("Generate Result"),
                        '10px',
                        'Center',
                        true,
                        [
                            {
                                Label: Core.Language.Translate('Close this dialog'),
                                Class: 'Primary',
                                Function: function () {
                                    Core.UI.Dialog.CloseDialog($('.NoSupportBunle'));
                                }
                            }
                        ],
                        true
                    );
                }
                else {

                    Core.UI.Dialog.ShowContentDialog(
                        $('#SupportBundleOptionsDialogContainer'), Core.Language.Translate("Support Bundle"),
                        '10px',
                        'Center',
                        true,
                        [
                            {
                                Label: Core.Language.Translate("Close this dialog"),
                                Class: 'Primary',
                                Function: function () {
                                    Core.UI.Dialog.CloseDialog($('#SupportBundleOptionsDialog'));
                                }
                            }
                        ],
                        true
                    );

                    $('#DownloadSupportBundle').on('click', function () {
                        window.location.href = Core.Config.Get('Baselink') + 'Action=' + Core.Config.Get('Action') + ';Subaction=DownloadSupportBundle;Filename=' + Response.Filename + ';RandomID=' + Response.RandomID + ';ChallengeToken=' + Core.Config.Get('ChallengeToken');
                        Core.UI.Dialog.CloseDialog($('#SupportBundleOptionsDialog'));
                    });
                }
            });

            Event.preventDefault();
            Event.stopPropagation();
            return false;
        });

        // Bind event on Details button
        $('.ShowItemMessage').on('click', function() {
            Core.UI.Dialog.ShowContentDialog($(this).next('.Hidden').html(), $(this).closest('tr').find('.ItemLabel').text(), '200px', 'Center');
            return false;
        });

        // Bind event on Data Table
        $('.DataTable').each(function() {
            if ($(this).find('.Flag.Problem').length) {
                $(this).prev('h3').find('.Flag').addClass('Problem');
                return true;
            }
            if ($(this).find('.Flag.Warning').length) {
                $(this).prev('h3').find('.Flag').addClass('Warning');
                return true;
            }
            if ($(this).find('.Flag.OK').length) {
                $(this).prev('h3').find('.Flag').addClass('OK');
                return true;
            }
            if ($(this).find('.Flag.Information').length) {
                $(this).prev('h3').find('.Flag').addClass('Information');
                return true;
            }
            if ($(this).find('.Flag.Unknown').length) {
                $(this).prev('h3').find('.Flag').addClass('Unknown');
                return true;
            }
        });

        // Bind event on Data Filter
        $('#SupportDataFilter').on('keyup', function(){
            var Filter = $('#SupportDataFilter').val().trim(),
                FilterRE = new RegExp(Filter, 'i'),
                VisibleCB = (Filter === undefined || Filter === '' || Filter == '*') ?
                function() {
                    return true;
                } :
                function(S) {
                    return S.match(FilterRE) != null;
                };

            $('div.WidgetSimple').each(function() {
                var $Sect = $(this),
                    IsVisible = false;

                $Sect.find('ul.CheckResults li').each(function() {
                    var $li = $(this),
                        Heading = $li.find('h3').filter(":first").text(),
                        HeadingIsVisible = VisibleCB(Heading);

                    if(HeadingIsVisible) {
                        IsVisible = true;
                    }
                    $li.css('display', HeadingIsVisible ? 'block' : 'none');
                });

                $Sect.css('display', IsVisible ? 'block' : 'none');
            });

            event.preventDefault();
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.SupportDataCollector || {}));
