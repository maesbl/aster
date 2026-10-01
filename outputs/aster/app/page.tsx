import Companion from "./companion";
import { requireChatGPTUser } from "./chatgpt-auth";

export default async function Home(){
 await requireChatGPTUser("/");
 return <Companion/>;
}
