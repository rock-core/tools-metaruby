/*
 * 
 * Plugin created by Andras Zoltan-Gyarfas -  azolee [at] gmail [dot] com
 * License: GNU License - http://www.gnu.org/licenses/gpl.html
 * Demo & latest release: http://realizare-site-web.ro/works/codes/jquery/HTML-Select-List-Filter/index.html
 * Last modification date: 04/20/2011
 * 
 */

;(function($) {
    $.fn.selectFilter = function() {
        var name = $(this).attr("name").replace(/\]/g, '').replace(/\[/g, '');
        $(this).addClass(name+"_select");
        var iname = name;
        $(this).before("<input class='"+iname+"' style='display: block;' type='text' />");
        $(this).css("display", "block");
        $("input."+name).live("keyup", function(){
            var txt = $(this).val().toLowerCase();

            var fields=txt.split(' ');
            var text = new Array();
            var tags = new Array();
            var tag_matcher = new RegExp("^tag:");
            for (var i = 0; i < fields.length; ++i) {
                var el = fields[i];
                if (tag_matcher.test(el)) {
                    el = el.split(':');
                    tags.push(new RegExp(el[1]));
                }
                else if (el.length != 0) {
                    text.push(new RegExp(el));
                }
            }

            if (text.length == 0 && tags.length == 0) {
                $("."+name+"_select").children('div').show();
            }
            else {
                $("."+name+"_select").children('div').hide();
                $("."+name+"_select").children('div').each(function(i, selected){
                    var value = $(this).text().toLowerCase();
                    var show = true;
                    for (var i = 0; show && i < text.length; ++i) {
                        if (!text[i].test(value)) {
                            show = false;
                        }
                    }
                    var value = $(this).attr('tags');
                    if (value) {
                        value = value.toLowerCase();
                        for (var i = 0; show && i < tags.length; ++i) {
                            if (!tags[i].test(value)) {
                                show = false;
                            }
                        }
                    }
                    if (show) {
                        $(selected).show();
                    }
                });
            }
        });
    return this;
    };
})(jQuery);
