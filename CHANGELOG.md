# Changelog

## [1.1.1](https://github.com/anteo/zoe-ai/compare/v1.1.0...v1.1.1) (2026-05-20)

## [1.1.0](https://github.com/anteo/zoe-ai/compare/v1.0.2...v1.1.0) (2026-05-19)

### Features

* **rate-limit:** add Rack::Attack throttling rules and integration tests ([6393f34](https://github.com/anteo/zoe-ai/commit/6393f34e2de5e817e8e24ed7c910a226e1cfe684))

## [1.0.2](https://github.com/anteo/zoe-ai/compare/v1.0.1...v1.0.2) (2026-05-18)

## [1.0.1](https://github.com/anteo/zoe-ai/compare/v1.0.0...v1.0.1) (2026-05-18)

## 1.0.0 (2026-05-18)

### Features

* add character bio field, sync on Turbo render, and improve UI details ([381de3e](https://github.com/anteo/zoe-ai/commit/381de3e8e05b1335183ee56e6e2a4f8c39fdb7cc))
* add character sharing via email with author ownership tracking ([346d4f5](https://github.com/anteo/zoe-ai/commit/346d4f5a5156c2616f681678812bc60abc17b7c2))
* add EnqueueFactAggregateSummariesJob to handle pending and failed summaries, decoupling enqueue from aggregation actor ([15caad2](https://github.com/anteo/zoe-ai/commit/15caad2c4a14769ac670f20bba272b1d1e11a37c))
* add self-registration setting and enforce when disabled ([fb5bbe3](https://github.com/anteo/zoe-ai/commit/fb5bbe33d4840284938e770373ca628945545962))
* **admin:** integrate Mission Control jobs dashboard as embedded modal ([aff35c5](https://github.com/anteo/zoe-ai/commit/aff35c539588294a6b4bdb312366504ad3b43991))
* **admin:** replace ConsoleLogger with persistent SystemLogger and level filtering ([02f304a](https://github.com/anteo/zoe-ai/commit/02f304a57acc52ea9d8c7e1edfac520af66e334b))
* **agents:** add settings section with CRUD and datatable component ([f4d28ae](https://github.com/anteo/zoe-ai/commit/f4d28aee68bbec443893256161edcf78f552d139))
* **characters:** migrate facts section to datatable component ([04923bc](https://github.com/anteo/zoe-ai/commit/04923bc77d4d52536c667eb1fa5e030f9ffbd16e))
* **characters:** restrict name editing for characters with facts or chat messages ([f56ab61](https://github.com/anteo/zoe-ai/commit/f56ab61a4092ce60f957893ccae53b313d5d8e45))
* **datatable:** add reusable datatable component with pagy, ransack, and Turbo Streams support ([a2dc615](https://github.com/anteo/zoe-ai/commit/a2dc615a9b22f4977087bc0401fabd6caa402f32))
* enable aggregate_persistent_facts recurring job ([7819bbf](https://github.com/anteo/zoe-ai/commit/7819bbf6e314a26c26f98727e4c46c6dfcd02b54))
* **instructions:** extract reusable editor component and add AI instructions settings section ([1e55bc3](https://github.com/anteo/zoe-ai/commit/1e55bc318089a8cc6797eb7c0a13e43832da9fec))
* **memory:** scope facts and aggregates by chat partner ([f97ff6c](https://github.com/anteo/zoe-ai/commit/f97ff6cf02f7a7e5c52492ae29e804f6b24ee024))
* **messages:** add error role for system error messages and exclude from LLM ([301efb7](https://github.com/anteo/zoe-ai/commit/301efb7f0fd3e6c1c0f37c74e786c7f4b2cb7f54))
* **models:** track stale registry entries and hide unavailable models ([f16cafa](https://github.com/anteo/zoe-ai/commit/f16cafa7ad51e576c62d56f193d8c1a4dd462e61))
* **profiles:** wrap name fields in responsive grid layout ([7ad6205](https://github.com/anteo/zoe-ai/commit/7ad6205c5791bda8b147cc7863d4af120dcdbdf6))
* **prompt:** restructure Zoe identity context with relation metadata ([6c29b6a](https://github.com/anteo/zoe-ai/commit/6c29b6ab72bc2f48b4f55c9da877444e0e663929))
* **routes:** redirect unauthenticated root to login ([168cf0e](https://github.com/anteo/zoe-ai/commit/168cf0ed9c0537f628786155eb3aa9826a812a57))
* **settings:** add MCP servers section with CodeMirror JSON editor and threaded sync ([df8f4ec](https://github.com/anteo/zoe-ai/commit/df8f4ecfe8bd323b40409fae329553b4220c88d5))
* **settings:** add model autocomplete and unified settings form flow ([6d4e1b3](https://github.com/anteo/zoe-ai/commit/6d4e1b3d67cb2be57b45c8c2a35b0db4a8b659fc))
* **settings:** finish settings forms and defaults ([4e0daed](https://github.com/anteo/zoe-ai/commit/4e0daed32be1df19c60889ea352024bc2a5d7570))
* **settings:** improve settings form presentation ([6d4ba53](https://github.com/anteo/zoe-ai/commit/6d4ba532e497be93d3b18a62728e04bf06d1e06f))
* **settings:** refine settings copy and layout ([149bd6d](https://github.com/anteo/zoe-ai/commit/149bd6d2748164296e9de888bc7268a5af9b85e0))
* **settings:** replace MCP servers table with datatable component ([8534608](https://github.com/anteo/zoe-ai/commit/8534608815cc78fca234dff8bf5cfe5a4c39d779))
* **theme:** extract theme picker into dedicated controller ([b0ca27d](https://github.com/anteo/zoe-ai/commit/b0ca27d7caf434e1bb01d325c4f15deb01cb90b5))
* **ui:** add search to chat history drawer ([676033a](https://github.com/anteo/zoe-ai/commit/676033ab3a8d9429ab5392820be84e98a5d245de))
* **ui:** allow admins to delete chats from history drawer ([c78fcfe](https://github.com/anteo/zoe-ai/commit/c78fcfe8e3cc817dfcac50e0fd6d4ac79f9bc692))
* **ui:** migrate modal interactions to turbo stream stack ([9706687](https://github.com/anteo/zoe-ai/commit/9706687b555b52a1d35f81ee597297f7e0213e3a))
* **ui:** replace custom history drawer with DaisyUI drawer and keyboard navigation ([c777900](https://github.com/anteo/zoe-ai/commit/c777900cbe41f02eea766f2df5718fd936a907e5))
* **ui:** replace vistaview with photoswipe for lightbox and add image dimensions ([01d2948](https://github.com/anteo/zoe-ai/commit/01d294870f457b13ee2012ed707fcbb9abeca731))
* **users:** skip email confirmation for first user ([e1e0fb6](https://github.com/anteo/zoe-ai/commit/e1e0fb65027b337f0887f2b306c6f0c26cfa5feb))

### Bug Fixes

* **agents:** disable blank model validation that caused premature error ([e221c5e](https://github.com/anteo/zoe-ai/commit/e221c5e5be612f3222ba1682270a3dd7bcc5e405))
* **chat-input:** prevent duplicate message submission on rapid Enter presses ([9422935](https://github.com/anteo/zoe-ai/commit/94229353e9a45188eebac5a518af8896aed2b957))
* **chats:** handle RubyLLM errors in token usage gauge and model resolution ([4fccd8d](https://github.com/anteo/zoe-ai/commit/4fccd8d419b975879d2964fd1416964293e553f8))
* **chats:** only run CloseStaleChatsJob in development ([952fe06](https://github.com/anteo/zoe-ai/commit/952fe060b707ff8dcbadec09a218239e4e35b3c3))
* **db:** remove unused vector extension from migration and schema ([eef577e](https://github.com/anteo/zoe-ai/commit/eef577e94e9a4bf67759d1f1d694036308ae4df9))
* **jobs:** prevent responding to non-replayable messages ([7424fcb](https://github.com/anteo/zoe-ai/commit/7424fcb01c67ad250156e3f28e4a24aa7e68f835))
* **logger:** pass logger to AI actor calls in jobs ([3f9dd40](https://github.com/anteo/zoe-ai/commit/3f9dd409bc9538035f5ba4836bf9bb70d2b76779))
* **logger:** pass logger to AI actor calls in jobs ([5a7f164](https://github.com/anteo/zoe-ai/commit/5a7f16456c8caa19499f75935a67ac71ce101b53))
* **logger:** support block/progname arguments and add source to job logs ([17ddbe0](https://github.com/anteo/zoe-ai/commit/17ddbe02911df993034d58c51feedeaeb0f30874))
* **models:** correct context lengths to powers of two and reduce max output tokens for some models ([8d5bc35](https://github.com/anteo/zoe-ai/commit/8d5bc351277d1c66a6b4a7b36c32d4ed971c9e0d))
* **models:** enforce not null on anchor_month and facts attributes ([e5a6562](https://github.com/anteo/zoe-ai/commit/e5a65627ecaf05e29ef29d1648ec2d98ed099ab3))
* **models:** use dependent :destroy for fact associations ([38c5677](https://github.com/anteo/zoe-ai/commit/38c56776b52c8097fb7d644e9ffe3b143be689b9))
* refactor DeepSeek patches into a single provider patch and update capabilities with dynamic pricing and reasoning detection ([a8e4688](https://github.com/anteo/zoe-ai/commit/a8e46887436c09546885853d4b21faa96f24e54c))
* **ui:** add turbo_frame to profile menu logout link ([0655bc8](https://github.com/anteo/zoe-ai/commit/0655bc85300d67a1857539dce47692ac1a9c9f8f))
* **ui:** refresh current chat view when deleted from history ([fb3df00](https://github.com/anteo/zoe-ai/commit/fb3df0067ba6d29ebbaaf018b2613c052a64ccba))
