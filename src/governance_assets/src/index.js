import { Actor, HttpAgent } from '@dfinity/agent';
import { idlFactory as governance_idl, canisterId as governance_id } from 'dfx-generated/governance';

const agent = new HttpAgent();
const governance = Actor.createActor(governance_idl, { agent, canisterId: governance_id });

document.getElementById("clickMeBtn").addEventListener("click", async () => {
  const name = document.getElementById("name").value.toString();
  const greeting = await governance.greet(name);

  document.getElementById("greeting").innerText = greeting;
});
