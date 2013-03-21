#!/bin/sh
/usr/local/mongodb-linux-x86_64-1.8.1/bin/mongo << !

use ygzj_dev;
//delete data before one month
prexTime = Math.round(new Date().getTime()/1000)-30*24*60*60;

//log_backout
db.log_backout.remove({time:{'\$lt':prexTime}});
//log_box_open
db.log_box_open.remove({open_time:{'\$lt':prexTime}});
//log_box_throw
db.log_box_throw.remove({time:{'\$lt':prexTime}});
//log_compose
db.log_compose.remove({time:{'\$lt':prexTime}});
//log_consign
db.log_consign.remove({timestamp:{'\$lt':prexTime}});
//log_consume
db.log_consume.remove({ct:{'\$lt':prexTime}});
//log_deliver
db.log_deliver.remove({timestamp:{'\$lt':prexTime}});
//log_employ
db.log_employ.remove({timestamp:{'\$lt':prexTime}});
//log_exc
db.log_exc.remove({this_beg_time:{'\$lt':prexTime}});
//log_exc_exp
db.log_exc_exp.remove({this_beg_time:{'\$lt':prexTime}});
//log_free_pet
db.log_free_pet.remove();
//log_hole
db.log_hole.remove({time:{'\$lt':prexTime}});
//log_icompose
db.log_icompose.remove({time:{'\$lt':prexTime}});
//log_idecompose
db.log_idecompose.remove({time:{'\$lt':prexTime}});
//log_identify
db.log_identify.remove({time:{'\$lt':prexTime}});
//log_inlay
db.log_inlay.remove({time:{'\$lt':prexTime}});
//log_linggen
db.log_linggen.remove({time:{'\$lt':prexTime}});
//log_mail
db.log_mail.remove({time:{'\$lt':prexTime}});
//log_merge
db.log_merge.remove({time:{'\$lt':prexTime}});
//log_meridian
db.log_meridian.remove({timestamp:{'\$lt':prexTime}});
//log_offline_award
db.log_offline_award.remove({timestamp:{'\$lt':prexTime}});
//log_online_cash
db.log_online_cash.remove({timestamp:{'\$lt':prexTime}});
//log_pet_aptitude
db.log_pet_aptitude.remove({time:{'\$lt':prexTime}});
//log_practise
db.log_practise.remove({time:{'\$lt':prexTime}});
//log_refine
db.log_refine.remove({time:{'\$lt':prexTime}});
//log_sale
db.log_sale.remove({deal_time:{'\$lt':prexTime}});
//log_sale_dir
db.log_sale_dir.remove({flow_time:{'\$lt':prexTime}});
//log_smelt
db.log_smelt.remove({time:{'\$lt':prexTime}});
//log_stren
db.log_stren.remove({time:{'\$lt':prexTime}});
//log_suitmerge
db.log_suitmerge.remove({time:{'\$lt':prexTime}});
//log_throw
db.log_throw.remove({time:{'\$lt':prexTime}});
//log_trade
db.log_trade.remove({deal_time:{'\$lt':prexTime}});
//log_uplevel
db.log_uplevel.remove({time:{'\$lt':prexTime}});
//log_warehouse_flowdir
db.log_warehouse_flowdir.remove({flow_time:{'\$lt':prexTime}});
//player_buff
db.player_buff.remove();

prexTime = Math.round(new Date().getTime()/1000)-15*24*60*60;
//mon_drop_analytics
db.mon_drop_analytics.remove({drop_time:{'\$lt':prexTime}});
//log_use
db.log_use.remove({time:{'\$lt':prexTime}});
db.log_use.remove({goods_id:23000});
db.log_use.remove({goods_id:23001});
db.log_use.remove({goods_id:23002});
db.log_use.remove({goods_id:23003});
db.log_use.remove({goods_id:23004});
db.log_use.remove({goods_id:23005});
db.log_use.remove({goods_id:23100});
db.log_use.remove({goods_id:23101});
db.log_use.remove({goods_id:23102});
db.log_use.remove({goods_id:23103});
db.log_use.remove({goods_id:23104});
db.log_use.remove({goods_id:23105});

//task_log
db.task_log.remove({task_id:{'\$gt':60000},finish_time:{'\$lt':prexTime}});
use ygfs;
print(db.player.find().count());
!
