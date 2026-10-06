import {withSecurity,json} from './_lib/security.js';
export default withSecurity(async(req,res)=>json(res,200,{ok:true}),{
 auth:'none',methods:['GET'],autoLog:false
});
